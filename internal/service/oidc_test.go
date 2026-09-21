package service

import (
	"testing"

	"github.com/nowen-reader/nowen-reader/internal/config"
)

// TestOIDCCallbackURLJoinsBasePath covers the root and sub-path cases, and
// guards against a double slash at the root.
func TestOIDCCallbackURLJoinsBasePath(t *testing.T) {
	t.Setenv("BASE_PATH", "/")
	if got := OIDCCallbackURL(); got != "/api/auth/oidc/callback" {
		t.Fatalf("root base path: got %q, want %q", got, "/api/auth/oidc/callback")
	}

	t.Setenv("BASE_PATH", "/reader")
	if got := OIDCCallbackURL(); got != "/reader/api/auth/oidc/callback" {
		t.Fatalf("nested base path: got %q, want %q", got, "/reader/api/auth/oidc/callback")
	}
}

// TestOIDCReadyReflectsConfig verifies readiness only when OIDC is enabled with
// both an issuer and a client id configured. No network access is performed.
func TestOIDCReadyReflectsConfig(t *testing.T) {
	t.Setenv("DATA_DIR", t.TempDir())

	config.SaveSiteConfig(&config.SiteConfig{})
	if OIDCReady() {
		t.Fatal("OIDCReady should be false when OIDC is unconfigured")
	}

	enabled := true
	config.SaveSiteConfig(&config.SiteConfig{
		OIDC: &config.OIDCConfig{
			Enabled:   &enabled,
			IssuerURL: "https://issuer.example.com",
			ClientID:  "client-id",
		},
	})
	if !OIDCReady() {
		t.Fatal("OIDCReady should be true when enabled with issuer and clientId")
	}

	config.SaveSiteConfig(&config.SiteConfig{
		OIDC: &config.OIDCConfig{Enabled: &enabled, ClientID: "client-id"},
	})
	if OIDCReady() {
		t.Fatal("OIDCReady should be false when the issuer is missing")
	}
}
