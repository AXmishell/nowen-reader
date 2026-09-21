package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/nowen-reader/nowen-reader/internal/model"
	"github.com/nowen-reader/nowen-reader/internal/store"
)

// setupBindTestRouter builds a test router whose schema includes the auth
// security tables (EmailToken etc.). setupTestRouter only creates the base
// schema; the production server additionally runs store.RunMigrations, so the
// bind test mirrors that.
func setupBindTestRouter(t *testing.T) *gin.Engine {
	t.Helper()
	r := setupTestRouter(t)
	if err := store.RunMigrations(); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}
	return r
}

func TestGenerateEmailCodeIsSixDigitNumeric(t *testing.T) {
	for i := 0; i < 100; i++ {
		code, err := generateEmailCode()
		if err != nil {
			t.Fatalf("generateEmailCode: %v", err)
		}
		if len(code) != emailCodeLength {
			t.Fatalf("code %q length = %d, want %d", code, len(code), emailCodeLength)
		}
		if _, err := strconv.Atoi(code); err != nil {
			t.Fatalf("code %q is not numeric: %v", code, err)
		}
	}
}

func TestHashEmailCodeIsStableAndNotPlaintext(t *testing.T) {
	const code = "012345"

	first := hashEmailCode(code)
	if first != hashEmailCode(code) {
		t.Fatal("hashEmailCode must be deterministic")
	}
	if first == code {
		t.Fatal("stored hash must not equal the plaintext code")
	}
	if len(first) != 64 {
		t.Fatalf("hash length = %d, want 64 (sha256 hex)", len(first))
	}
	if first == hashEmailCode("543210") {
		t.Fatal("distinct codes must hash differently")
	}
}

func TestAuthConfigGetNeverExposesPassword(t *testing.T) {
	r := setupTestRouter(t)
	cookie := registerAndLogin(t, r)

	w := performAuthedRequest(r, "GET", "/api/admin/auth-config", nil, cookie)
	if w.Code != http.StatusOK {
		t.Fatalf("GET auth-config = %d %s", w.Code, w.Body.String())
	}

	var resp map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("parse response: %v", err)
	}
	smtp, ok := resp["smtp"].(map[string]interface{})
	if !ok {
		t.Fatal("response must contain an smtp object")
	}
	if _, exists := smtp["password"]; exists {
		t.Fatal("smtp password must never be returned")
	}
	if _, exists := smtp["passwordSet"]; !exists {
		t.Fatal("smtp.passwordSet boolean is required")
	}
	if _, exists := resp["emailVerificationRequired"]; !exists {
		t.Fatal("emailVerificationRequired missing")
	}
	if _, exists := resp["emailCodeLoginEnabled"]; !exists {
		t.Fatal("emailCodeLoginEnabled missing")
	}
}

func TestEmailSendRejectsInvalidPurpose(t *testing.T) {
	r := setupTestRouter(t)

	w := performRequest(r, "POST", "/api/auth/email/send", map[string]string{
		"email":   "user@example.com",
		"purpose": "bogus",
	})
	if w.Code != http.StatusBadRequest {
		t.Fatalf("invalid purpose = %d %s, want 400", w.Code, w.Body.String())
	}
}

func TestBindSendRejectsInvalidEmail(t *testing.T) {
	r := setupBindTestRouter(t)
	cookie := registerAndLogin(t, r)

	w := performAuthedRequest(r, "POST", "/api/auth/email/bind/send", map[string]string{
		"email": "not-an-email",
	}, cookie)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("invalid email = %d %s, want 400", w.Code, w.Body.String())
	}
}

func TestBindSendRejectsWhenSMTPUnconfigured(t *testing.T) {
	r := setupBindTestRouter(t)
	cookie := registerAndLogin(t, r)

	w := performAuthedRequest(r, "POST", "/api/auth/email/bind/send", map[string]string{
		"email": "new@example.com",
	}, cookie)
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("unconfigured SMTP = %d %s, want 503", w.Code, w.Body.String())
	}
}

func TestBindSendRequiresSession(t *testing.T) {
	r := setupBindTestRouter(t)

	w := performRequest(r, "POST", "/api/auth/email/bind/send", map[string]string{
		"email": "new@example.com",
	})
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("no session = %d %s, want 401", w.Code, w.Body.String())
	}
}

func TestBindVerifyRejectsMissingToken(t *testing.T) {
	r := setupBindTestRouter(t)
	cookie := registerAndLogin(t, r)

	w := performAuthedRequest(r, "POST", "/api/auth/email/bind/verify", map[string]string{
		"email": "new@example.com",
		"code":  "123456",
	}, cookie)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("missing token = %d %s, want 400", w.Code, w.Body.String())
	}
}

func TestBindVerifyRejectsTokenOwnedByAnotherUser(t *testing.T) {
	r := setupBindTestRouter(t)
	cookie := registerAndLogin(t, r)

	// A real second account owns the pending token; the EmailToken.userId FK
	// requires the row to exist.
	other := &model.User{
		ID:       "bind-other-user",
		Username: "bind-other-user",
		Password: "unused",
		Nickname: "Other",
		Role:     "user",
	}
	if err := store.CreateUser(other); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}

	const email = "claimed@example.com"
	// The token carries the correct code so that, absent the ownership check,
	// verification would succeed. A 400 therefore proves the ownership guard.
	token := &model.EmailToken{
		ID:        "other-user-bind-token",
		UserID:    other.ID,
		Email:     email,
		Purpose:   emailPurposeBind,
		CodeHash:  hashEmailCode("123456"),
		ExpiresAt: time.Now().Add(10 * time.Minute),
	}
	if err := store.CreateEmailToken(token); err != nil {
		t.Fatalf("CreateEmailToken: %v", err)
	}

	w := performAuthedRequest(r, "POST", "/api/auth/email/bind/verify", map[string]string{
		"email": email,
		"code":  "123456",
	}, cookie)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("token owned by another user = %d %s, want 400", w.Code, w.Body.String())
	}
}
