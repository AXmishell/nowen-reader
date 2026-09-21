package handler

import (
	"encoding/json"
	"net/http"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/pquerna/otp/totp"

	"github.com/nowen-reader/nowen-reader/internal/middleware"
	"github.com/nowen-reader/nowen-reader/internal/store"
)

// TestTOTPEnrollmentLoginChallengeAndDisable drives the full two-factor flow
// over the real router + SQLite test database. It uses no SMTP or network.
func TestTOTPEnrollmentLoginChallengeAndDisable(t *testing.T) {
	// Keep the AES-GCM key material out of the repository .cache directory.
	t.Setenv("DATA_DIR", t.TempDir())

	r := setupTestRouter(t)
	if err := store.RunMigrations(); err != nil {
		t.Fatalf("RunMigrations failed: %v", err)
	}
	cookie := registerAndLogin(t, r)

	if totpStatus(t, r, cookie) {
		t.Fatal("TOTP should start disabled")
	}

	// Setup hands back the plaintext secret + provisioning URI exactly once.
	w := performAuthedRequest(r, "POST", "/api/auth/totp/setup", nil, cookie)
	if w.Code != http.StatusOK {
		t.Fatalf("setup = %d %s", w.Code, w.Body.String())
	}
	var setupResp struct {
		Secret     string `json:"secret"`
		OtpauthURL string `json:"otpauthUrl"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &setupResp); err != nil {
		t.Fatalf("parse setup response: %v", err)
	}
	if setupResp.Secret == "" || setupResp.OtpauthURL == "" {
		t.Fatalf("setup response missing secret/otpauthUrl: %s", w.Body.String())
	}

	// A wrong code must not enable the factor.
	w = performAuthedRequest(r, "POST", "/api/auth/totp/enable", map[string]string{"code": "000000"}, cookie)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("enable with wrong code = %d %s, want 400", w.Code, w.Body.String())
	}
	if totpStatus(t, r, cookie) {
		t.Fatal("TOTP must stay disabled after a wrong code")
	}

	// A valid code enables and mints recovery codes returned exactly once.
	code, err := totp.GenerateCode(setupResp.Secret, time.Now())
	if err != nil {
		t.Fatalf("generate code: %v", err)
	}
	w = performAuthedRequest(r, "POST", "/api/auth/totp/enable", map[string]string{"code": code}, cookie)
	if w.Code != http.StatusOK {
		t.Fatalf("enable = %d %s", w.Code, w.Body.String())
	}
	var enableResp struct {
		RecoveryCodes []string `json:"recoveryCodes"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &enableResp); err != nil {
		t.Fatalf("parse enable response: %v", err)
	}
	if len(enableResp.RecoveryCodes) != 10 {
		t.Fatalf("recovery codes = %d, want 10", len(enableResp.RecoveryCodes))
	}
	if !totpStatus(t, r, cookie) {
		t.Fatal("TOTP should be enabled after a valid code")
	}

	// Login now issues a challenge instead of a session.
	challengeID := loginChallenge(t, r)
	sessionCookie := verifyChallenge(t, r, challengeID, enableResp.RecoveryCodes[0], http.StatusOK)
	if sessionCookie == "" {
		t.Fatal("verify did not return a session cookie")
	}

	// A recovery code is single-use: replaying it must fail.
	challengeID = loginChallenge(t, r)
	verifyChallenge(t, r, challengeID, enableResp.RecoveryCodes[0], http.StatusUnauthorized)

	// Disable with a live TOTP code clears the factor.
	code, err = totp.GenerateCode(setupResp.Secret, time.Now())
	if err != nil {
		t.Fatalf("generate code: %v", err)
	}
	w = performAuthedRequest(r, "POST", "/api/auth/totp/disable", map[string]string{"code": code}, sessionCookie)
	if w.Code != http.StatusOK {
		t.Fatalf("disable = %d %s", w.Code, w.Body.String())
	}
	if totpStatus(t, r, cookie) {
		t.Fatal("TOTP should be disabled after disable")
	}
}

// TestAuthConfigExposesTotpSectionWithoutSecrets verifies the admin auth-config
// exposes the TOTP knobs without ever returning secret material.
func TestAuthConfigExposesTotpSectionWithoutSecrets(t *testing.T) {
	r := setupTestRouter(t)
	cookie := registerAndLogin(t, r)

	w := performAuthedRequest(r, "GET", "/api/admin/auth-config", nil, cookie)
	if w.Code != http.StatusOK {
		t.Fatalf("GET auth-config = %d %s", w.Code, w.Body.String())
	}
	var resp map[string]json.RawMessage
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("parse response: %v", err)
	}
	raw, ok := resp["totp"]
	if !ok {
		t.Fatal("auth-config must include a totp section")
	}
	var totp map[string]interface{}
	if err := json.Unmarshal(raw, &totp); err != nil {
		t.Fatalf("parse totp section: %v", err)
	}
	for _, key := range []string{"enabled", "requiredForAdmins", "issuer"} {
		if _, exists := totp[key]; !exists {
			t.Fatalf("totp section missing %q", key)
		}
	}
	if _, leaked := resp["totpSecret"]; leaked {
		t.Fatal("auth-config must never expose a TOTP secret")
	}
}

func totpStatus(t *testing.T, r *gin.Engine, cookie string) bool {
	t.Helper()
	w := performAuthedRequest(r, "GET", "/api/auth/totp/status", nil, cookie)
	if w.Code != http.StatusOK {
		t.Fatalf("status = %d %s", w.Code, w.Body.String())
	}
	var resp struct {
		Enabled bool `json:"enabled"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("parse status: %v", err)
	}
	return resp.Enabled
}

func loginChallenge(t *testing.T, r *gin.Engine) string {
	t.Helper()
	w := performRequest(r, "POST", "/api/auth/login", map[string]string{
		"username": "admin",
		"password": "password123",
	})
	if w.Code != http.StatusOK {
		t.Fatalf("login = %d %s", w.Code, w.Body.String())
	}
	var resp struct {
		TOTPRequired bool   `json:"totpRequired"`
		ChallengeID  string `json:"challengeId"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("parse login: %v", err)
	}
	if !resp.TOTPRequired || resp.ChallengeID == "" {
		t.Fatalf("login should require TOTP, got %s", w.Body.String())
	}
	return resp.ChallengeID
}

func verifyChallenge(t *testing.T, r *gin.Engine, challengeID, code string, wantCode int) string {
	t.Helper()
	w := performRequest(r, "POST", "/api/auth/totp/verify", map[string]string{
		"challengeId": challengeID,
		"code":        code,
	})
	if w.Code != wantCode {
		t.Fatalf("verify = %d %s, want %d", w.Code, w.Body.String(), wantCode)
	}
	if wantCode != http.StatusOK {
		return ""
	}
	var cookie string
	for _, c := range w.Result().Cookies() {
		if c.Name == middleware.SessionCookie {
			cookie = c.Value
		}
	}
	return cookie
}
