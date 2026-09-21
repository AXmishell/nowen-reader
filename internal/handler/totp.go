package handler

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/nowen-reader/nowen-reader/internal/config"
	"github.com/nowen-reader/nowen-reader/internal/middleware"
	"github.com/nowen-reader/nowen-reader/internal/model"
	"github.com/nowen-reader/nowen-reader/internal/security"
	"github.com/nowen-reader/nowen-reader/internal/service"
	"github.com/nowen-reader/nowen-reader/internal/store"
)

const (
	// authPurposeTOTP tags the AuthChallenge row issued for a pending TOTP step-up.
	authPurposeTOTP = "totp"
	// authChallengeTTL is how long a login challenge stays valid before the
	// client must restart the login flow.
	authChallengeTTL = 5 * time.Minute
	// recoveryCodeCount is the number of single-use backup codes minted at enable.
	recoveryCodeCount = 10
)

// TOTPHandler handles two-factor (TOTP) enrollment and step-up verification.
type TOTPHandler struct{}

// NewTOTPHandler creates a new TOTPHandler.
func NewTOTPHandler() *TOTPHandler {
	return &TOTPHandler{}
}

// requireSessionUser returns the fully-loaded user for the current browser
// session, or nil after writing a 401. SessionRequired has already validated the
// credential, so GetCurrentUser only resolves it; the DB load refreshes the
// TOTP state that the AuthUser projection omits.
func requireSessionUser(c *gin.Context) *model.User {
	authUser := middleware.GetCurrentUser(c)
	if authUser == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return nil
	}
	user, err := store.GetUserByID(authUser.ID)
	if err != nil || user == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return nil
	}
	return user
}

// verifyCodeOrRecovery accepts a current TOTP code or, failing that, an unused
// recovery code. A matching recovery code is consumed when consume is true.
func verifyCodeOrRecovery(user *model.User, code string, consume bool) bool {
	code = strings.TrimSpace(code)
	if code == "" {
		return false
	}
	if secret, err := security.Decrypt(user.TotpSecret); err == nil && service.ValidateTOTP(secret, code) {
		return true
	}
	recovery, err := store.GetUnusedRecoveryCode(user.ID, service.HashRecoveryCode(code))
	if err != nil || recovery == nil {
		return false
	}
	if consume {
		if err := store.MarkRecoveryCodeUsed(recovery.ID); err != nil {
			return false
		}
	}
	return true
}

// Setup handles POST /api/auth/totp/setup. It stores a fresh encrypted secret
// and returns the plaintext secret + otpauth URI once, but does not enable TOTP
// until the user proves possession via Enable.
func (h *TOTPHandler) Setup(c *gin.Context) {
	user := requireSessionUser(c)
	if user == nil {
		return
	}
	if user.TotpEnabled {
		c.JSON(http.StatusBadRequest, gin.H{"error": "TOTP is already enabled"})
		return
	}

	secret, otpauthURL, err := service.GenerateTOTP(user.Username, config.GetTOTP().Issuer)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate TOTP secret"})
		return
	}
	encrypted, err := security.Encrypt(secret)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to store TOTP secret"})
		return
	}
	if err := store.UpdateUserTotpSecret(user.ID, encrypted); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to store TOTP secret"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"secret": secret, "otpauthUrl": otpauthURL})
}

// Enable handles POST /api/auth/totp/enable. On a valid code it flips the flag
// and returns the freshly minted recovery codes exactly once.
func (h *TOTPHandler) Enable(c *gin.Context) {
	user := requireSessionUser(c)
	if user == nil {
		return
	}

	var req struct {
		Code string `json:"code"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}
	if user.TotpEnabled {
		c.JSON(http.StatusBadRequest, gin.H{"error": "TOTP is already enabled"})
		return
	}
	if strings.TrimSpace(user.TotpSecret) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "TOTP setup has not been started"})
		return
	}

	secret, err := security.Decrypt(user.TotpSecret)
	if err != nil || secret == "" {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read TOTP secret"})
		return
	}
	if !service.ValidateTOTP(secret, req.Code) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid verification code"})
		return
	}

	codes, err := service.GenerateRecoveryCodes(recoveryCodeCount)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate recovery codes"})
		return
	}
	records := make([]*model.TOTPRecoveryCode, 0, len(codes))
	for _, code := range codes {
		records = append(records, &model.TOTPRecoveryCode{
			ID:       uuid.New().String(),
			UserID:   user.ID,
			CodeHash: service.HashRecoveryCode(code),
		})
	}
	if err := store.CreateTOTPRecoveryCodes(records); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to store recovery codes"})
		return
	}
	if err := store.UpdateUserTotpEnabled(user.ID, true); err != nil {
		_ = store.DeleteTOTPRecoveryCodesByUser(user.ID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to enable TOTP"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"recoveryCodes": codes})
}

// Disable handles POST /api/auth/totp/disable. A valid TOTP code or an unused
// recovery code removes the second factor and all backup codes.
func (h *TOTPHandler) Disable(c *gin.Context) {
	user := requireSessionUser(c)
	if user == nil {
		return
	}

	var req struct {
		Code string `json:"code"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}
	if !user.TotpEnabled {
		c.JSON(http.StatusBadRequest, gin.H{"error": "TOTP is not enabled"})
		return
	}
	if !verifyCodeOrRecovery(user, req.Code, true) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid verification code"})
		return
	}

	if err := store.UpdateUserTotpEnabled(user.ID, false); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to disable TOTP"})
		return
	}
	if err := store.UpdateUserTotpSecret(user.ID, ""); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to disable TOTP"})
		return
	}
	if err := store.DeleteTOTPRecoveryCodesByUser(user.ID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to disable TOTP"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}

// Status handles GET /api/auth/totp/status.
func (h *TOTPHandler) Status(c *gin.Context) {
	user := requireSessionUser(c)
	if user == nil {
		return
	}
	c.JSON(http.StatusOK, gin.H{"enabled": user.TotpEnabled})
}

// Verify handles POST /api/auth/totp/verify, completing the login challenge
// issued by issueSessionOrTOTPChallenge. It accepts a TOTP code or a single-use
// recovery code and, on success, consumes the challenge and creates a session.
func (h *TOTPHandler) Verify(c *gin.Context) {
	var req struct {
		ChallengeID string `json:"challengeId"`
		Code        string `json:"code"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}
	challengeID := strings.TrimSpace(req.ChallengeID)
	if challengeID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "challengeId is required"})
		return
	}

	challenge, err := store.GetActiveAuthChallenge(challengeID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	if challenge == nil || challenge.Purpose != authPurposeTOTP {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid or expired challenge"})
		return
	}

	user, err := store.GetUserByID(challenge.UserID)
	if err != nil || user == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid or expired challenge"})
		return
	}
	if !verifyCodeOrRecovery(user, req.Code, true) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid verification code"})
		return
	}

	if err := store.ConsumeAuthChallenge(challenge.ID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete login"})
		return
	}
	token := uuid.New().String()
	session := &model.UserSession{
		ID:        token,
		UserID:    user.ID,
		ExpiresAt: time.Now().Add(time.Duration(middleware.SessionMaxAge) * time.Second),
	}
	if err := store.CreateSession(session); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create session"})
		return
	}
	middleware.SetSessionCookie(c, token)

	c.JSON(http.StatusOK, gin.H{"user": authUserPayload(user)})
}
