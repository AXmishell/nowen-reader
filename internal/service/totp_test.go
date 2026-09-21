package service

import (
	"strings"
	"testing"
	"time"

	"github.com/pquerna/otp/totp"
)

func TestGenerateTOTP_ProvisionsValidatableSecret(t *testing.T) {
	secret, otpauthURL, err := GenerateTOTP("alice", "NowenTest")
	if err != nil {
		t.Fatalf("GenerateTOTP: %v", err)
	}
	if secret == "" {
		t.Fatal("GenerateTOTP returned an empty secret")
	}
	if !strings.HasPrefix(otpauthURL, "otpauth://totp/") {
		t.Fatalf("otpauthURL = %q, want otpauth://totp/ prefix", otpauthURL)
	}
	if !strings.Contains(otpauthURL, "issuer=NowenTest") {
		t.Fatalf("otpauthURL = %q, want issuer=NowenTest", otpauthURL)
	}

	code, err := totp.GenerateCode(secret, time.Now())
	if err != nil {
		t.Fatalf("generate code from returned secret: %v", err)
	}
	if !ValidateTOTP(secret, code) {
		t.Fatalf("ValidateTOTP rejected code %q generated from its own secret", code)
	}
}

func TestValidateTOTP_RejectsWrongAndEmpty(t *testing.T) {
	secret, _, err := GenerateTOTP("bob", "NowenTest")
	if err != nil {
		t.Fatalf("GenerateTOTP: %v", err)
	}

	if ValidateTOTP(secret, "") {
		t.Fatal("ValidateTOTP accepted an empty code")
	}
	if ValidateTOTP("", "123456") {
		t.Fatal("ValidateTOTP accepted an empty secret")
	}

	code, err := totp.GenerateCode(secret, time.Now())
	if err != nil {
		t.Fatalf("generate code: %v", err)
	}
	wrong := "000000"
	if wrong == code {
		wrong = "111111"
	}
	if ValidateTOTP(secret, wrong) {
		t.Fatalf("ValidateTOTP accepted the wrong code %q", wrong)
	}
}

func TestGenerateRecoveryCodes_FormatAndUniqueness(t *testing.T) {
	codes, err := GenerateRecoveryCodes(10)
	if err != nil {
		t.Fatalf("GenerateRecoveryCodes: %v", err)
	}
	if len(codes) != 10 {
		t.Fatalf("len(codes) = %d, want 10", len(codes))
	}

	seen := make(map[string]struct{}, len(codes))
	allowed := make(map[rune]struct{}, len(recoveryCodeAlphabet))
	for _, r := range recoveryCodeAlphabet {
		allowed[r] = struct{}{}
	}
	for _, code := range codes {
		if len(code) != recoveryCodeGroups*recoveryCodeGroupLen+(recoveryCodeGroups-1) {
			t.Fatalf("code %q has unexpected shape", code)
		}
		if code[recoveryCodeGroupLen] != '-' {
			t.Fatalf("code %q is missing the dash separator", code)
		}
		if _, dup := seen[code]; dup {
			t.Fatalf("duplicate recovery code %q", code)
		}
		seen[code] = struct{}{}
		for _, r := range strings.ReplaceAll(code, "-", "") {
			if _, ok := allowed[r]; !ok {
				t.Fatalf("code %q contains disallowed character %q", code, r)
			}
		}
	}

	empty, err := GenerateRecoveryCodes(0)
	if err != nil || len(empty) != 0 {
		t.Fatalf("GenerateRecoveryCodes(0) = %v, %v; want empty, nil", empty, err)
	}
}

func TestNormalizeRecoveryCode_Canonical(t *testing.T) {
	cases := map[string]string{
		"abcd-efgh":     "ABCDEFGH",
		"ABCD EFGH":     "ABCDEFGH",
		"  AbCd-EfGh  ": "ABCDEFGH",
		"":              "",
	}
	for input, want := range cases {
		if got := NormalizeRecoveryCode(input); got != want {
			t.Fatalf("NormalizeRecoveryCode(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestHashRecoveryCode_StableAcrossFormatting(t *testing.T) {
	canonical := HashRecoveryCode("ABCD-EFGH")
	if canonical != HashRecoveryCode("abcd efgh") {
		t.Fatal("HashRecoveryCode must ignore case and separators")
	}
	if len(canonical) != 64 {
		t.Fatalf("hash length = %d, want 64 (sha256 hex)", len(canonical))
	}
	if canonical == NormalizeRecoveryCode("ABCD-EFGH") {
		t.Fatal("stored hash must not equal the plaintext code")
	}
	if canonical == HashRecoveryCode("ABCD-EFGI") {
		t.Fatal("distinct recovery codes must hash differently")
	}
}
