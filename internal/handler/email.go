package handler

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"fmt"
	"math/big"
	"net/http"
	"net/mail"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/nowen-reader/nowen-reader/internal/config"
	"github.com/nowen-reader/nowen-reader/internal/model"
	"github.com/nowen-reader/nowen-reader/internal/service"
	"github.com/nowen-reader/nowen-reader/internal/store"
)

const (
	emailCodeLength      = 6
	emailCodeTTL         = 10 * time.Minute
	emailCodeMaxAttempts = 5
	emailPurposeVerify   = "verify"
	emailPurposeLogin    = "login"
)

// EmailHandler handles email verification and email-code login endpoints.
type EmailHandler struct{}

// NewEmailHandler creates a new EmailHandler.
func NewEmailHandler() *EmailHandler {
	return &EmailHandler{}
}

// generateEmailCode returns a zero-padded 6-digit numeric code.
func generateEmailCode() (string, error) {
	upperBound := big.NewInt(1000000)
	n, err := rand.Int(rand.Reader, upperBound)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

// hashEmailCode returns the SHA-256 hex digest of a code. Only the hash is
// persisted; plaintext codes never touch the database.
func hashEmailCode(code string) string {
	digest := sha256.Sum256([]byte(code))
	return hex.EncodeToString(digest[:])
}

// createAndSendEmailCode generates a code, stores its hash with an expiry, then
// sends it. Callers decide whether a failure is fatal.
func createAndSendEmailCode(userID, email, purpose string) error {
	code, err := generateEmailCode()
	if err != nil {
		return err
	}
	token := &model.EmailToken{
		ID:        uuid.New().String(),
		UserID:    userID,
		Email:     email,
		Purpose:   purpose,
		CodeHash:  hashEmailCode(code),
		ExpiresAt: time.Now().Add(emailCodeTTL),
	}
	if err := store.CreateEmailToken(token); err != nil {
		return err
	}
	return service.SendVerificationCode(email, code, purpose)
}

// SendCode handles POST /api/auth/email/send.
// To avoid account enumeration it always returns {"success": true} when the
// request is well-formed, even if no matching account exists.
func (h *EmailHandler) SendCode(c *gin.Context) {
	var req struct {
		Email   string `json:"email"`
		Purpose string `json:"purpose"`
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

	purpose := strings.ToLower(strings.TrimSpace(req.Purpose))
	if purpose != emailPurposeVerify && purpose != emailPurposeLogin {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid purpose"})
		return
	}
	if purpose == emailPurposeLogin && !config.IsEmailCodeLoginEnabled() {
		c.JSON(http.StatusForbidden, gin.H{"error": "Email code login is disabled"})
		return
	}
	if !service.IsConfigured() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "SMTP 未配置"})
		return
	}

	user, err := store.GetUserByEmail(email)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	switch purpose {
	case emailPurposeVerify:
		if user == nil || user.EmailVerified {
			c.JSON(http.StatusOK, gin.H{"success": true})
			return
		}
	case emailPurposeLogin:
		if user == nil || !user.EmailVerified {
			c.JSON(http.StatusOK, gin.H{"success": true})
			return
		}
	}

	if err := createAndSendEmailCode(user.ID, email, purpose); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send verification code"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// VerifyCode handles POST /api/auth/email/verify.
func (h *EmailHandler) VerifyCode(c *gin.Context) {
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

	token, err := store.GetActiveEmailToken(email, emailPurposeVerify)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	if token == nil {
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

	if err := store.ConsumeEmailToken(token.ID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify email"})
		return
	}
	if err := store.UpdateUserEmailVerified(token.UserID, true); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify email"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// LoginWithCode handles POST /api/auth/email/login.
func (h *EmailHandler) LoginWithCode(c *gin.Context) {
	var req struct {
		Email string `json:"email"`
		Code  string `json:"code"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if !config.IsEmailCodeLoginEnabled() {
		c.JSON(http.StatusForbidden, gin.H{"error": "Email code login is disabled"})
		return
	}

	email := strings.TrimSpace(req.Email)
	code := strings.TrimSpace(req.Code)
	if _, err := mail.ParseAddress(email); err != nil || code == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or code"})
		return
	}

	user, err := store.GetUserByEmail(email)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	// Generic failure keeps account existence hidden.
	if user == nil || !user.EmailVerified {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or code"})
		return
	}

	emailToken, err := store.GetActiveEmailToken(email, emailPurposeLogin)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	if emailToken == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or code"})
		return
	}
	if emailToken.Attempts >= emailCodeMaxAttempts {
		c.JSON(http.StatusTooManyRequests, gin.H{"error": "Too many attempts"})
		return
	}
	if subtle.ConstantTimeCompare([]byte(hashEmailCode(code)), []byte(emailToken.CodeHash)) != 1 {
		_ = store.IncrementEmailTokenAttempts(emailToken.ID)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or code"})
		return
	}

	if err := store.ConsumeEmailToken(emailToken.ID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to log in"})
		return
	}

	// Second-factor step-up (when enrolled) or session creation, shared with Login.
	issueSessionOrTOTPChallenge(c, user)
}
