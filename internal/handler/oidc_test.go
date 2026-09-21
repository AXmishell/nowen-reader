package handler

import (
	"encoding/json"
	"net/http"
	"testing"

	"github.com/nowen-reader/nowen-reader/internal/config"
)

// TestOIDCProvidersEmptyWhenDisabled verifies the public discovery endpoint
// degrades to an empty provider list instead of failing. No network is touched.
func TestOIDCProvidersEmptyWhenDisabled(t *testing.T) {
	t.Setenv("DATA_DIR", t.TempDir())
	config.SaveSiteConfig(&config.SiteConfig{})

	r := setupTestRouter(t)
	w := performRequest(r, "GET", "/api/auth/oidc/providers", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("providers = %d %s, want 200", w.Code, w.Body.String())
	}
	var resp struct {
		Providers []json.RawMessage `json:"providers"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("parse providers: %v", err)
	}
	if len(resp.Providers) != 0 {
		t.Fatalf("providers = %s, want an empty list", w.Body.String())
	}
}

// TestOIDCEndpointsReturn404WhenDisabled verifies the login and callback
// endpoints refuse to run while OIDC is disabled.
func TestOIDCEndpointsReturn404WhenDisabled(t *testing.T) {
	t.Setenv("DATA_DIR", t.TempDir())
	config.SaveSiteConfig(&config.SiteConfig{})

	r := setupTestRouter(t)
	for _, path := range []string{"/api/auth/oidc/login", "/api/auth/oidc/callback"} {
		w := performRequest(r, "GET", path, nil)
		if w.Code != http.StatusNotFound {
			t.Fatalf("%s when disabled = %d %s, want 404", path, w.Code, w.Body.String())
		}
	}
}

// TestAuthConfigOIDCSectionNeverExposesSecret verifies the admin auth-config
// round-trips the OIDC section without ever returning the client secret, and
// that an empty secret preserves the stored value.
func TestAuthConfigOIDCSectionNeverExposesSecret(t *testing.T) {
	t.Setenv("DATA_DIR", t.TempDir())
	t.Setenv("BASE_PATH", "/")
	config.SaveSiteConfig(&config.SiteConfig{})

	r := setupTestRouter(t)
	cookie := registerAndLogin(t, r)

	w := performAuthedRequest(r, "PUT", "/api/admin/auth-config", map[string]interface{}{
		"oidc": map[string]interface{}{
			"enabled":         true,
			"issuerUrl":       "https://issuer.example.com",
			"clientId":        "client-id",
			"clientSecret":    "super-secret",
			"autoCreateUsers": true,
		},
	}, cookie)
	if w.Code != http.StatusOK {
		t.Fatalf("PUT auth-config = %d %s", w.Code, w.Body.String())
	}

	w = performAuthedRequest(r, "GET", "/api/admin/auth-config", nil, cookie)
	if w.Code != http.StatusOK {
		t.Fatalf("GET auth-config = %d %s", w.Code, w.Body.String())
	}
	var resp map[string]json.RawMessage
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("parse response: %v", err)
	}
	raw, ok := resp["oidc"]
	if !ok {
		t.Fatal("auth-config must include an oidc section")
	}
	var section map[string]interface{}
	if err := json.Unmarshal(raw, &section); err != nil {
		t.Fatalf("parse oidc section: %v", err)
	}
	if _, leaked := section["clientSecret"]; leaked {
		t.Fatal("auth-config must never expose clientSecret")
	}
	if section["clientSecretSet"] != true {
		t.Fatalf("clientSecretSet = %v, want true", section["clientSecretSet"])
	}
	if section["enabled"] != true {
		t.Fatalf("enabled = %v, want true", section["enabled"])
	}
	if section["callbackUrl"] != "/api/auth/oidc/callback" {
		t.Fatalf("callbackUrl = %v, want /api/auth/oidc/callback", section["callbackUrl"])
	}

	// An empty secret must preserve the stored one.
	w = performAuthedRequest(r, "PUT", "/api/admin/auth-config", map[string]interface{}{
		"oidc": map[string]interface{}{"clientSecret": ""},
	}, cookie)
	if w.Code != http.StatusOK {
		t.Fatalf("PUT preserve secret = %d %s", w.Code, w.Body.String())
	}
	if stored := config.GetOIDC().ClientSecret; stored != "super-secret" {
		t.Fatalf("stored secret = %q, want it preserved", stored)
	}
}

// TestAuthConfigOIDCRequiresIssuerAndClientWhenEnabled verifies the enable-time
// validation rejects an incomplete configuration.
func TestAuthConfigOIDCRequiresIssuerAndClientWhenEnabled(t *testing.T) {
	t.Setenv("DATA_DIR", t.TempDir())
	config.SaveSiteConfig(&config.SiteConfig{})

	r := setupTestRouter(t)
	cookie := registerAndLogin(t, r)

	w := performAuthedRequest(r, "PUT", "/api/admin/auth-config", map[string]interface{}{
		"oidc": map[string]interface{}{"enabled": true},
	}, cookie)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("enabling OIDC without issuer/clientId = %d %s, want 400", w.Code, w.Body.String())
	}
}
