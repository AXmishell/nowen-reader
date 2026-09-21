package service

import (
	"strings"
	"testing"

	"github.com/nowen-reader/nowen-reader/internal/config"
)

// unconfiguredSMTP points config at an empty temp data dir so SMTP is off.
// It avoids any real network call.
func unconfiguredSMTP(t *testing.T) {
	t.Helper()
	t.Setenv("DATA_DIR", t.TempDir())
	if err := config.SaveSiteConfig(&config.SiteConfig{}); err != nil {
		t.Fatalf("SaveSiteConfig: %v", err)
	}
	if IsConfigured() {
		t.Fatal("expected SMTP to be unconfigured")
	}
}

func TestSendVerificationCodeFailsWhenSMTPDisabled(t *testing.T) {
	unconfiguredSMTP(t)

	err := SendVerificationCode("user@example.com", "123456", "verify")
	if err == nil {
		t.Fatal("expected an error when SMTP is unconfigured")
	}
	if !strings.Contains(err.Error(), "SMTP") {
		t.Fatalf("error = %q, want it to mention SMTP", err.Error())
	}
}

func TestSendTestEmailFailsWhenSMTPDisabled(t *testing.T) {
	unconfiguredSMTP(t)

	if err := SendTestEmail("user@example.com"); err == nil {
		t.Fatal("expected an error when SMTP is unconfigured")
	}
}

func TestVerificationCodeContentVariesByPurpose(t *testing.T) {
	t.Setenv("DATA_DIR", t.TempDir())
	if err := config.SaveSiteConfig(&config.SiteConfig{SiteName: "TestSite"}); err != nil {
		t.Fatalf("SaveSiteConfig: %v", err)
	}

	verifySubject, verifyText, verifyHTML := verificationCodeContent("verify", "111111")
	loginSubject, loginText, loginHTML := verificationCodeContent("login", "222222")

	if verifySubject == loginSubject {
		t.Fatalf("expected distinct subjects, both = %q", verifySubject)
	}
	if !strings.Contains(verifySubject, "TestSite") || !strings.Contains(loginSubject, "TestSite") {
		t.Fatalf("subjects must contain the site name: %q / %q", verifySubject, loginSubject)
	}
	if !strings.Contains(verifyText, "111111") || !strings.Contains(verifyHTML, "111111") {
		t.Fatal("verify bodies must embed the code")
	}
	if !strings.Contains(loginText, "222222") || !strings.Contains(loginHTML, "222222") {
		t.Fatal("login bodies must embed the code")
	}
	if !strings.Contains(verifyText, "10 分钟") {
		t.Fatal("verify body must state the 10-minute TTL")
	}
}
