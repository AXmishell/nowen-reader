package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"testing"
)

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
