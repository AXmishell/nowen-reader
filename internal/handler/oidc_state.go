package handler

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/nowen-reader/nowen-reader/internal/config"
	"github.com/nowen-reader/nowen-reader/internal/security"
)

const (
	// oidcStateCookie carries the encrypted, short-lived OIDC handshake state.
	oidcStateCookie = "nowen_oidc_state"
	// oidcStateTTL bounds how long a started authorization may complete.
	oidcStateTTL = 10 * time.Minute
	// Byte lengths for the random state, nonce and PKCE verifier values.
	oidcStateBytes    = 32
	oidcNonceBytes    = 16
	oidcVerifierBytes = 32
)

// oidcStatePayload is the per-round-trip browser state. It is JSON-encoded and
// AES-GCM encrypted before being placed in the state cookie, so the browser
// never observes the state, nonce or PKCE verifier in plaintext.
type oidcStatePayload struct {
	State      string `json:"state"`
	Nonce      string `json:"nonce"`
	Verifier   string `json:"verifier"`
	LinkUserID string `json:"linkUserId,omitempty"`
	Exp        int64  `json:"exp"`
}

// oidcRandomToken returns n cryptographically random bytes as base64url text.
func oidcRandomToken(n int) (string, error) {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}

// writeStateCookie encrypts and stores the handshake payload.
func (h *OIDCHandler) writeStateCookie(c *gin.Context, payload oidcStatePayload) error {
	raw, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	encrypted, err := security.Encrypt(string(raw))
	if err != nil {
		return err
	}
	c.SetSameSite(http.SameSiteLaxMode)
	c.SetCookie(oidcStateCookie, encrypted, int(oidcStateTTL.Seconds()), config.BasePath(), "", false, true)
	return nil
}

// readStateCookie decrypts and validates the handshake payload, including its
// expiry.
func (h *OIDCHandler) readStateCookie(c *gin.Context) (*oidcStatePayload, error) {
	raw, err := c.Cookie(oidcStateCookie)
	if err != nil || raw == "" {
		return nil, errors.New("oidc: missing state cookie")
	}
	decrypted, err := security.Decrypt(raw)
	if err != nil {
		return nil, errors.New("oidc: invalid state cookie")
	}
	payload := &oidcStatePayload{}
	if err := json.Unmarshal([]byte(decrypted), payload); err != nil {
		return nil, errors.New("oidc: malformed state payload")
	}
	if payload.Exp < time.Now().Unix() {
		return nil, errors.New("oidc: expired state")
	}
	return payload, nil
}

// clearStateCookie always removes the one-shot handshake cookie.
func (h *OIDCHandler) clearStateCookie(c *gin.Context) {
	c.SetSameSite(http.SameSiteLaxMode)
	c.SetCookie(oidcStateCookie, "", -1, config.BasePath(), "", false, true)
}
