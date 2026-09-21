package handler

import (
	"crypto/subtle"
	"encoding/json"
	"html"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/nowen-reader/nowen-reader/internal/config"
	"github.com/nowen-reader/nowen-reader/internal/middleware"
	"github.com/nowen-reader/nowen-reader/internal/model"
	"github.com/nowen-reader/nowen-reader/internal/service"
	"github.com/nowen-reader/nowen-reader/internal/store"
)

// oidcErrorQueryKey names the short error code the SPA reads after a failure.
const oidcErrorQueryKey = "oidc_error"

// OIDCHandler handles OpenID Connect login, account linking and identity
// management endpoints.
type OIDCHandler struct{}

// NewOIDCHandler creates a new OIDCHandler.
func NewOIDCHandler() *OIDCHandler {
	return &OIDCHandler{}
}

// oidcClaimString reads a claims value as a trimmed string.
func oidcClaimString(claims map[string]any, key string) string {
	value, _ := claims[key].(string)
	return strings.TrimSpace(value)
}

// oidcClaimBool reads a claims value as a boolean, failing closed for any other
// JSON type so a coerced/non-boolean claim can never be treated as true.
func oidcClaimBool(claims map[string]any, key string) bool {
	value, _ := claims[key].(bool)
	return value
}

// oidcAppRoot returns the SPA root for the current base path, always with a
// trailing slash so query parameters can be appended directly.
func oidcAppRoot() string {
	base := config.BasePath()
	if base == "/" {
		return "/"
	}
	return base + "/"
}

// redirectSelfDriven sends a 302 with a Location header AND a tiny HTML body
// that navigates itself (meta refresh + JS). Some reverse proxies and embedded
// browsers render a redirect's response body instead of following the
// redirect, which leaves the user on a page showing only Go's default
// "Found" link; a self-driving body removes that extra click.
func redirectSelfDriven(c *gin.Context, location string) {
	escaped := html.EscapeString(location)
	// JS string literal（正确转义引号/反斜杠等），与 HTML 转义分开处理。
	script, err := json.Marshal(location)
	if err != nil {
		script = []byte(`""`)
	}

	c.Header("Cache-Control", "no-store")
	c.Header("Location", location)
	c.Data(http.StatusFound, "text/html; charset=utf-8", []byte(
		`<!DOCTYPE html><html lang="zh-CN"><head><meta charset="utf-8">`+
			`<meta http-equiv="refresh" content="0;url=`+escaped+`">`+
			`<title>正在跳转…</title></head><body>`+
			`<script>location.replace(`+string(script)+`);</script>`+
			`<p>正在跳转…若浏览器没有自动跳转，请<a href="`+escaped+`">点击继续</a>。</p>`+
			`</body></html>`))
}

// redirectOIDCError sends the browser back to the SPA with a short error code.
func redirectOIDCError(c *gin.Context, code string) {
	redirectSelfDriven(c, oidcAppRoot()+"?"+oidcErrorQueryKey+"="+url.QueryEscape(code))
}

// completeOIDCLogin finishes the browser authorization-code flow. Because the
// callback is reached by a top-level navigation, it must always redirect: to the
// SPA root on success, or with the TOTP challenge id when a second factor is
// required. The session cookie is set on the redirect response.
func completeOIDCLogin(c *gin.Context, user *model.User) {
	outcome, err := beginSessionOrChallenge(user)
	if err != nil {
		redirectOIDCError(c, "internal")
		return
	}
	if outcome.Challenge != nil {
		redirectSelfDriven(c, oidcAppRoot()+"?oidc=totp&challengeId="+url.QueryEscape(outcome.Challenge.ID))
		return
	}
	middleware.SetSessionCookie(c, outcome.SessionToken)
	redirectSelfDriven(c, oidcAppRoot()+"?oidc=ok")
}

// beginAuthorization generates and stores a fresh state/nonce/verifier triple,
// then redirects to the provider (or writes an error response).
func (h *OIDCHandler) beginAuthorization(c *gin.Context, linkUserID string) {
	if !service.OIDCReady() {
		c.JSON(http.StatusNotFound, gin.H{"error": "OIDC is not enabled"})
		return
	}

	// 若身份提供商把 redirect_uri 配成了本端点（而不是
	// /api/auth/oidc/callback），授权完成后浏览器会带着 code/state 回到这里。
	// 此时若重新发起授权就会形成无限跳转循环，因此直接给出可诊断的错误。
	if c.Query("code") != "" || c.Query("state") != "" || c.Query("error") != "" {
		log.Printf("[oidc] %s received an authorization response; the provider's redirect URI must be /api/auth/oidc/callback, not this endpoint", c.Request.URL.Path)
		redirectOIDCError(c, "wrong_endpoint")
		return
	}

	state, err := oidcRandomToken(oidcStateBytes)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start OIDC login"})
		return
	}
	nonce, err := oidcRandomToken(oidcNonceBytes)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start OIDC login"})
		return
	}
	verifier, err := oidcRandomToken(oidcVerifierBytes)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start OIDC login"})
		return
	}

	if err := h.writeStateCookie(c, oidcStatePayload{
		State:      state,
		Nonce:      nonce,
		Verifier:   verifier,
		LinkUserID: linkUserID,
		Exp:        time.Now().Add(oidcStateTTL).Unix(),
	}); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start OIDC login"})
		return
	}

	// redirect_uri 必须是绝对地址，且与 IdP 白名单完全一致（授权请求与换取
	// token 的请求必须用同一个值）。这里由当前请求推导；当反向代理未透传
	// https 时，可用 PUBLIC_URL 显式指定对外地址。
	redirectURI := absoluteCallbackURL(c, service.OIDCCallbackURL())
	authURL, err := service.OIDCAuthCodeURL(state, nonce, verifier, redirectURI)
	if err != nil {
		h.clearStateCookie(c)
		c.JSON(http.StatusBadGateway, gin.H{"error": "Failed to reach the OIDC provider"})
		return
	}
	redirectSelfDriven(c, authURL)
}

// Providers handles GET /api/auth/oidc/providers. It is public so the login
// screen can discover whether to render the SSO button.
func (h *OIDCHandler) Providers(c *gin.Context) {
	if !service.OIDCReady() {
		c.JSON(http.StatusOK, gin.H{"providers": []gin.H{}})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"providers": []gin.H{{"id": "default", "label": config.GetOIDC().ButtonLabel}},
	})
}

// Login handles GET /api/auth/oidc/login and starts a fresh login flow.
func (h *OIDCHandler) Login(c *gin.Context) {
	h.beginAuthorization(c, "")
}

// Link handles GET /api/auth/oidc/link: the same flow, but it binds the
// resulting identity to the currently authenticated session user.
func (h *OIDCHandler) Link(c *gin.Context) {
	authUser := middleware.GetCurrentUser(c)
	if authUser == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	h.beginAuthorization(c, authUser.ID)
}

// Callback handles GET /api/auth/oidc/callback, the single entry point that
// consumes the encrypted state cookie.
//
// Both failure and success are expressed as browser redirects, because the
// authorization-code flow is always a top-level navigation: any failure goes to
// the SPA root with ?oidc_error=<short-code>, and success goes to the SPA root
// with ?oidc=ok (session cookie set on the redirect) or
// ?oidc=totp&challengeId=<id> when a second factor is still required.
func (h *OIDCHandler) Callback(c *gin.Context) {
	defer h.clearStateCookie(c)

	if !service.OIDCReady() {
		c.JSON(http.StatusNotFound, gin.H{"error": "OIDC is not enabled"})
		return
	}
	if c.Query("error") != "" {
		redirectOIDCError(c, "provider")
		return
	}

	state, err := h.readStateCookie(c)
	if err != nil {
		redirectOIDCError(c, "state")
		return
	}
	if subtle.ConstantTimeCompare([]byte(c.Query("state")), []byte(state.State)) != 1 {
		redirectOIDCError(c, "state")
		return
	}

	code := c.Query("code")
	if code == "" {
		redirectOIDCError(c, "code")
		return
	}

	idToken, claims, err := service.OIDCExchange(
		c.Request.Context(),
		code,
		state.Verifier,
		absoluteCallbackURL(c, service.OIDCCallbackURL()),
	)
	if err != nil {
		redirectOIDCError(c, "exchange")
		return
	}
	if subtle.ConstantTimeCompare([]byte(idToken.Nonce), []byte(state.Nonce)) != 1 {
		redirectOIDCError(c, "nonce")
		return
	}

	issuer := idToken.Issuer
	subject := oidcClaimString(claims, "sub")
	if subject == "" {
		redirectOIDCError(c, "claims")
		return
	}
	email := oidcClaimString(claims, "email")
	emailVerified := oidcClaimBool(claims, "email_verified")

	if state.LinkUserID != "" {
		user, errCode := h.linkIdentity(issuer, subject, email, state.LinkUserID)
		if errCode != "" {
			redirectOIDCError(c, errCode)
			return
		}
		completeOIDCLogin(c, user)
		return
	}

	user, errCode := h.resolveIdentityUser(issuer, subject, email, emailVerified, claims)
	if errCode != "" {
		redirectOIDCError(c, errCode)
		return
	}
	completeOIDCLogin(c, user)
}

// Identities handles GET /api/auth/oidc/identities and returns the current
// user's linked identities as a JSON array.
func (h *OIDCHandler) Identities(c *gin.Context) {
	authUser := middleware.GetCurrentUser(c)
	if authUser == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	identities, err := store.ListOIDCIdentitiesByUser(authUser.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to list OIDC identities"})
		return
	}
	result := make([]gin.H, 0, len(identities))
	for _, identity := range identities {
		result = append(result, gin.H{
			"id":      identity.ID,
			"issuer":  identity.Issuer,
			"subject": identity.Subject,
			"email":   identity.Email,
		})
	}
	c.JSON(http.StatusOK, result)
}

// Unbind handles DELETE /api/auth/oidc/identities/:id. It only unlinks an
// identity that belongs to the current session user.
func (h *OIDCHandler) Unbind(c *gin.Context) {
	authUser := middleware.GetCurrentUser(c)
	if authUser == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	identityID := strings.TrimSpace(c.Param("id"))
	if identityID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Identity id is required"})
		return
	}

	identities, err := store.ListOIDCIdentitiesByUser(authUser.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load OIDC identities"})
		return
	}
	owned := false
	for _, identity := range identities {
		if identity.ID == identityID {
			owned = true
			break
		}
	}
	if !owned {
		c.JSON(http.StatusNotFound, gin.H{"error": "OIDC identity not found"})
		return
	}

	if err := store.DeleteOIDCIdentity(identityID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unlink OIDC identity"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}
