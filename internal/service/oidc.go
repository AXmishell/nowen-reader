package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/coreos/go-oidc/v3/oidc"
	"golang.org/x/oauth2"

	"github.com/nowen-reader/nowen-reader/internal/config"
)

const (
	// oidcProviderCacheTTL bounds how long a discovered provider is reused
	// before discovery is retried.
	oidcProviderCacheTTL = 10 * time.Minute
	// oidcDiscoveryTimeout caps a single discovery HTTP round-trip.
	oidcDiscoveryTimeout = 15 * time.Second
)

// oidcProviderEntry caches a discovered provider together with the
// configuration signature it was built from.
type oidcProviderEntry struct {
	signature string
	provider  *oidc.Provider
	verifier  *oidc.IDTokenVerifier
	fetchedAt time.Time
}

var (
	oidcProviderMu    sync.Mutex
	oidcProviderCache *oidcProviderEntry
)

// OIDCReady reports whether OIDC login is configured and enabled.
func OIDCReady() bool {
	return config.IsOIDCEnabled()
}

// OIDCCallbackURL returns the redirect URI the provider must call back, joined
// with the configured base path (without producing a double slash at "/").
func OIDCCallbackURL() string {
	base := config.BasePath()
	if base == "/" {
		return "/api/auth/oidc/callback"
	}
	return base + "/api/auth/oidc/callback"
}

// oidcProviderSignature identifies the settings a cached provider was built for.
func oidcProviderSignature(cfg config.OIDCConfig) string {
	return cfg.IssuerURL + "|" + cfg.ClientID
}

// resolveOIDCProvider returns the cached provider/verifier pair, re-running
// discovery when the issuer/client changed or the cache entry outlived its TTL.
func resolveOIDCProvider(ctx context.Context, cfg config.OIDCConfig) (*oidc.Provider, *oidc.IDTokenVerifier, error) {
	signature := oidcProviderSignature(cfg)

	oidcProviderMu.Lock()
	cached := oidcProviderCache
	oidcProviderMu.Unlock()

	if cached != nil && cached.signature == signature && time.Since(cached.fetchedAt) < oidcProviderCacheTTL {
		return cached.provider, cached.verifier, nil
	}

	discoveryCtx, cancel := context.WithTimeout(ctx, oidcDiscoveryTimeout)
	defer cancel()
	provider, err := oidc.NewProvider(discoveryCtx, cfg.IssuerURL)
	if err != nil {
		return nil, nil, fmt.Errorf("oidc: provider discovery failed: %w", err)
	}
	verifier := provider.Verifier(&oidc.Config{ClientID: cfg.ClientID})

	oidcProviderMu.Lock()
	oidcProviderCache = &oidcProviderEntry{
		signature: signature,
		provider:  provider,
		verifier:  verifier,
		fetchedAt: time.Now(),
	}
	oidcProviderMu.Unlock()

	return provider, verifier, nil
}

// oidcOAuthConfig builds the OAuth2 client configuration for the current
// settings. redirectURL must be the ABSOLUTE callback URL registered at the
// provider: OIDC providers reject a relative redirect_uri, and the value must
// match exactly between the authorization request and the token exchange.
// When empty it falls back to the base-path-relative path, which is only useful
// for local debugging.
func oidcOAuthConfig(cfg config.OIDCConfig, endpoint oauth2.Endpoint, redirectURL string) oauth2.Config {
	if strings.TrimSpace(redirectURL) == "" {
		redirectURL = OIDCCallbackURL()
	}
	return oauth2.Config{
		ClientID:     cfg.ClientID,
		ClientSecret: cfg.ClientSecret,
		Endpoint:     endpoint,
		RedirectURL:  redirectURL,
		Scopes:       strings.Fields(cfg.Scopes),
	}
}

// OIDCAuthCodeURL builds the provider authorization URL carrying the supplied
// state and nonce together with the PKCE S256 challenge.
//
// redirectURL is the absolute callback URL the provider must redirect back to;
// pass the same value to OIDCExchange so the token request matches.
func OIDCAuthCodeURL(state, nonce, codeVerifier, redirectURL string) (string, error) {
	cfg := config.GetOIDC()
	provider, _, err := resolveOIDCProvider(context.Background(), cfg)
	if err != nil {
		return "", err
	}
	oauthCfg := oidcOAuthConfig(cfg, provider.Endpoint(), redirectURL)
	return oauthCfg.AuthCodeURL(
		state,
		oauth2.SetAuthURLParam("nonce", nonce),
		oauth2.S256ChallengeOption(codeVerifier),
	), nil
}

// OIDCExchange swaps an authorization code for tokens and verifies the returned
// ID token (issuer, audience, expiry and signature), returning the verified
// token plus its decoded claims.
//
// redirectURL must be the same absolute callback URL that was sent with the
// authorization request (RFC 6749 requires the token request to repeat it).
//
// The caller must still validate idToken.Nonce against the nonce it stored for
// this round-trip, and must treat the claims as untrusted input.
func OIDCExchange(ctx context.Context, code, codeVerifier, redirectURL string) (*oidc.IDToken, map[string]any, error) {
	cfg := config.GetOIDC()
	provider, verifier, err := resolveOIDCProvider(ctx, cfg)
	if err != nil {
		return nil, nil, err
	}
	oauthCfg := oidcOAuthConfig(cfg, provider.Endpoint(), redirectURL)

	token, err := oauthCfg.Exchange(ctx, code, oauth2.VerifierOption(codeVerifier))
	if err != nil {
		return nil, nil, fmt.Errorf("oidc: token exchange failed: %w", err)
	}
	rawIDToken, ok := token.Extra("id_token").(string)
	if !ok || rawIDToken == "" {
		return nil, nil, errors.New("oidc: token response is missing id_token")
	}
	idToken, err := verifier.Verify(ctx, rawIDToken)
	if err != nil {
		return nil, nil, fmt.Errorf("oidc: id_token verification failed: %w", err)
	}
	claims := map[string]any{}
	if err := idToken.Claims(&claims); err != nil {
		return nil, nil, fmt.Errorf("oidc: decode id_token claims: %w", err)
	}
	return idToken, claims, nil
}
