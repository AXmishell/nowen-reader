package handler

import (
	"crypto/subtle"
	"net/http"
	"net/mail"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/nowen-reader/nowen-reader/internal/middleware"
	"github.com/nowen-reader/nowen-reader/internal/service"
	"github.com/nowen-reader/nowen-reader/internal/store"
)

// BindSend handles POST /api/auth/email/bind/send. It issues a one-time code to
// the new address a logged-in user wants to bind to their own account.
//
// The flow is code-verified only. Requiring the account password again before
// binding is a possible future hardening step; it is intentionally omitted here
// so legacy accounts (no password-equivalent email on file) can still self-bind.
func (h *EmailHandler) BindSend(c *gin.Context) {
	currentUser := middleware.GetCurrentUser(c)
	if currentUser == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var req struct {
		Email string `json:"email"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	email := strings.TrimSpace(req.Email)
	if _, err := mail.ParseAddress(email); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid email address"})
		return
	}
	if !service.IsConfigured() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "SMTP 未配置"})
		return
	}

	owner, err := store.GetUserByEmail(email)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	// Rebinding to the caller's own current email is allowed; only another
	// account owning the address is a conflict.
	if owner != nil && owner.ID != currentUser.ID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email already exists"})
		return
	}

	if err := createAndSendEmailCode(currentUser.ID, email, emailPurposeBind); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send verification code"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// BindVerify handles POST /api/auth/email/bind/verify. It proves ownership of
// the pending address, then makes it the account's verified email.
func (h *EmailHandler) BindVerify(c *gin.Context) {
	currentUser := middleware.GetCurrentUser(c)
	if currentUser == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var req struct {
		Email string `json:"email"`
		Code  string `json:"code"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	email := strings.TrimSpace(req.Email)
	code := strings.TrimSpace(req.Code)
	if _, err := mail.ParseAddress(email); err != nil || code == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	token, err := store.GetActiveEmailToken(email, emailPurposeBind)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	if token == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid or expired code"})
		return
	}
	// A bind token belongs to the session that requested it; never let another
	// session consume someone else's binding token.
	if token.UserID != currentUser.ID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid or expired code"})
		return
	}
	if token.Attempts >= emailCodeMaxAttempts {
		c.JSON(http.StatusTooManyRequests, gin.H{"error": "Too many attempts"})
		return
	}
	if subtle.ConstantTimeCompare([]byte(hashEmailCode(code)), []byte(token.CodeHash)) != 1 {
		_ = store.IncrementEmailTokenAttempts(token.ID)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid or expired code"})
		return
	}

	// Re-check uniqueness: another account may have claimed the address while
	// this code was outstanding. Leave the token unconsumed on conflict so a
	// later retry can still fail loudly.
	owner, err := store.GetUserByEmail(email)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	if owner != nil && owner.ID != currentUser.ID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email already exists"})
		return
	}

	if err := store.ConsumeEmailToken(token.ID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to bind email"})
		return
	}
	// Ownership was proven by the emailed code, so the address is verified.
	if err := store.UpdateUserEmail(currentUser.ID, email, true); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to bind email"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}
