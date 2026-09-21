package handler

import (
	"log"
	"net/http"
	"net/mail"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"github.com/nowen-reader/nowen-reader/internal/config"
	"github.com/nowen-reader/nowen-reader/internal/middleware"
	"github.com/nowen-reader/nowen-reader/internal/model"
	"github.com/nowen-reader/nowen-reader/internal/service"
	"github.com/nowen-reader/nowen-reader/internal/store"
)

// AuthHandler handles all auth-related API endpoints.
type AuthHandler struct{}

func NewAuthHandler() *AuthHandler {
	return &AuthHandler{}
}

// authUserPayload builds the safe user object returned to clients on a
// successful login (session or TOTP step-up).
func authUserPayload(user *model.User) model.AuthUser {
	return model.AuthUser{
		ID:            user.ID,
		Username:      user.Username,
		Nickname:      user.Nickname,
		Role:          user.Role,
		AiEnabled:     user.AiEnabled,
		Email:         user.Email,
		EmailVerified: user.EmailVerified,
		TotpEnabled:   user.TotpEnabled,
	}
}

// mustSetupTotp reports whether admins are required to use TOTP but this admin
// has not yet enrolled. It is a soft nudge: login still succeeds, because a hard
// gate here would lock admins out before they can reach the enrollment screen.
func mustSetupTotp(user *model.User) bool {
	return config.GetTOTP().RequiredForAdmins && user.Role == "admin" && !user.TotpEnabled
}

// sessionOrChallenge is the outcome of starting a first-factor login: exactly
// one of SessionToken or Challenge is set.
type sessionOrChallenge struct {
	SessionToken string
	Challenge    *model.AuthChallenge
}

// beginSessionOrChallenge creates either a session for user (returning its
// token) or, when the account has TOTP enabled, a short-lived challenge. It
// writes no HTTP response so callers can choose between JSON and a redirect.
func beginSessionOrChallenge(user *model.User) (*sessionOrChallenge, error) {
	if user.TotpEnabled {
		challenge := &model.AuthChallenge{
			ID:        uuid.New().String(),
			UserID:    user.ID,
			Purpose:   authPurposeTOTP,
			ExpiresAt: time.Now().Add(authChallengeTTL),
		}
		if err := store.CreateAuthChallenge(challenge); err != nil {
			return nil, err
		}
		return &sessionOrChallenge{Challenge: challenge}, nil
	}

	token := uuid.New().String()
	session := &model.UserSession{
		ID:        token,
		UserID:    user.ID,
		ExpiresAt: time.Now().Add(time.Duration(middleware.SessionMaxAge) * time.Second),
	}
	if err := store.CreateSession(session); err != nil {
		return nil, err
	}
	return &sessionOrChallenge{SessionToken: token}, nil
}

// issueSessionOrTOTPChallenge writes the JSON login response for the API
// clients. It returns true when a TOTP challenge was issued (no session
// created); otherwise it creates the session, sets the cookie and returns false.
func issueSessionOrTOTPChallenge(c *gin.Context, user *model.User) bool {
	outcome, err := beginSessionOrChallenge(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create session"})
		return false
	}
	if outcome.Challenge != nil {
		c.JSON(http.StatusOK, gin.H{
			"totpRequired": true,
			"challengeId":  outcome.Challenge.ID,
		})
		return true
	}

	middleware.SetSessionCookie(c, outcome.SessionToken)
	resp := gin.H{"user": authUserPayload(user)}
	if mustSetupTotp(user) {
		resp["mustSetupTotp"] = true
	}
	c.JSON(http.StatusOK, resp)
	return false
}

// Register handles POST /api/auth/register
func (h *AuthHandler) Register(c *gin.Context) {
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
		Nickname string `json:"nickname"`
		Email    string `json:"email"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if req.Username == "" || req.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Username and password are required"})
		return
	}
	if len(req.Username) < 3 || len(req.Username) > 32 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Username must be 3-32 characters"})
		return
	}
	if len(req.Password) < 6 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Password must be at least 6 characters"})
		return
	}

	// 检查注册策略（第一个用户始终允许注册）
	userCount, err := store.CountUsers()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	if userCount > 0 {
		mode := config.GetRegistrationMode()
		if mode == "closed" {
			c.JSON(http.StatusForbidden, gin.H{"error": "Registration is closed"})
			return
		}
		if mode == "invite" {
			// 仅管理员可以通过管理界面创建用户，普通注册被禁止
			c.JSON(http.StatusForbidden, gin.H{"error": "Registration requires an invitation from admin"})
			return
		}
	}

	// Check if username already exists
	existing, err := store.GetUserByUsername(req.Username)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	if existing != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Username already exists"})
		return
	}

	// 邮箱：策略要求时必须提供；提供时校验格式并拒绝重复。
	email := strings.TrimSpace(req.Email)
	if email != "" {
		if _, err := mail.ParseAddress(email); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid email address"})
			return
		}
		emailUser, err := store.GetUserByEmail(email)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}
		if emailUser != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Email already exists"})
			return
		}
	} else if config.IsEmailVerificationRequired() {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email is required"})
		return
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), 10)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	// First user is admin
	role := "user"
	if userCount == 0 {
		role = "admin"
	}

	nickname := req.Nickname
	if nickname == "" {
		nickname = req.Username
	}

	user := &model.User{
		ID:        uuid.New().String(),
		Username:  req.Username,
		Password:  string(hashedPassword),
		Nickname:  nickname,
		Role:      role,
		AiEnabled: role == "admin", // 管理员默认启用 AI
		Email:     email,           // EmailVerified 保持 false，待邮箱验证
	}

	if err := store.CreateUser(user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Registration failed"})
		return
	}

	// 已配置邮件时下发验证码；发送失败只记录日志，不影响注册结果。
	if user.Email != "" && service.IsConfigured() {
		if err := createAndSendEmailCode(user.ID, user.Email, emailPurposeVerify); err != nil {
			log.Printf("[auth] failed to send verification code to %s: %v", user.Email, err)
		}
	}

	// Auto-login after registration
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

	c.JSON(http.StatusOK, gin.H{
		"user": authUserPayload(user),
	})
}

// Login handles POST /api/auth/login
func (h *AuthHandler) Login(c *gin.Context) {
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if req.Username == "" || req.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Username and password are required"})
		return
	}

	user, err := store.GetUserByUsername(req.Username)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	if user == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid username or password"})
		return
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid username or password"})
		return
	}

	// 邮箱验证策略：仅当账号已填写邮箱但尚未验证时才禁止登录。
	// 管理员豁免以避免把自己锁在门外；未填写邮箱的旧账号（email 为空）同样放行，
	// 否则这些用户永远无法登录并进入账户面板自助绑定邮箱。
	if config.IsEmailVerificationRequired() && user.Role != "admin" && user.Email != "" && !user.EmailVerified {
		c.JSON(http.StatusForbidden, gin.H{"error": "Email not verified"})
		return
	}

	issueSessionOrTOTPChallenge(c, user)
}

// Logout handles POST /api/auth/logout
func (h *AuthHandler) Logout(c *gin.Context) {
	token, err := c.Cookie(middleware.SessionCookie)
	if err == nil && token != "" {
		_ = store.DeleteSession(token)
	}

	middleware.ClearSessionCookie(c)
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// Me handles GET /api/auth/me
func (h *AuthHandler) Me(c *gin.Context) {
	hasUsers, err := store.CountUsers()
	if err != nil {
		// 数据库出错时返回500，避免前端误以为未登录而跳转到登录页
		log.Printf("[Auth] CountUsers error in /api/auth/me: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	if hasUsers == 0 {
		c.JSON(http.StatusOK, gin.H{"user": nil, "needsSetup": true})
		return
	}

	user := middleware.GetCurrentUser(c)
	if c.GetHeader("Authorization") != "" && user == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"user":             user,
		"needsSetup":       false,
		"registrationMode": config.GetRegistrationMode(),
	})
}

// ListUsers handles GET /api/auth/users (admin only)
func (h *AuthHandler) ListUsers(c *gin.Context) {
	currentUser := middleware.GetCurrentUser(c)
	if currentUser == nil || currentUser.Role != "admin" {
		c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
		return
	}

	users, err := store.ListUsers()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to list users"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"users": users})
}

// UpdateUser handles PUT /api/auth/users
func (h *AuthHandler) UpdateUser(c *gin.Context) {
	currentUser := middleware.GetCurrentUser(c)
	if currentUser == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var req struct {
		Action      string `json:"action"`
		UserID      string `json:"userId"`
		OldPassword string `json:"oldPassword"`
		NewPassword string `json:"newPassword"`
		Nickname    string `json:"nickname"`
		Role        string `json:"role"`
		AiEnabled   bool   `json:"aiEnabled"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	switch req.Action {
	case "changePassword":
		targetID := req.UserID
		if targetID == "" {
			targetID = currentUser.ID
		}
		// Non-admin can only change own password
		if targetID != currentUser.ID && currentUser.Role != "admin" {
			c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
			return
		}

		user, err := store.GetUserByID(targetID)
		if err != nil || user == nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User not found"})
			return
		}

		if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.OldPassword)); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Current password is incorrect"})
			return
		}

		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), 10)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
			return
		}

		if err := store.UpdateUserPassword(targetID, string(hashedPassword)); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update password"})
			return
		}

		// Invalidate all other sessions for this user (security best practice)
		currentToken, _ := c.Cookie(middleware.SessionCookie)
		if err := store.DeleteSessionsByUserID(targetID, currentToken); err != nil {
			// Non-fatal: log but don't fail the request
			log.Printf("[auth] Warning: failed to cleanup sessions after password change for user %s: %v", targetID, err)
		}

		c.JSON(http.StatusOK, gin.H{"success": true})

	case "updateProfile":
		targetID := req.UserID
		if targetID == "" {
			targetID = currentUser.ID
		}
		if targetID != currentUser.ID && currentUser.Role != "admin" {
			c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
			return
		}

		if err := store.UpdateUserProfile(targetID, req.Nickname); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update profile"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"success": true})

	case "updateRole":
		if currentUser.Role != "admin" {
			c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
			return
		}
		if req.UserID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "userId is required"})
			return
		}
		if req.UserID == currentUser.ID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot change your own role"})
			return
		}
		newRole := req.Role
		if newRole != "admin" && newRole != "user" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid role, must be 'admin' or 'user'"})
			return
		}
		if err := store.UpdateUserRole(req.UserID, newRole); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update role"})
			return
		}
		// 管理员自动启用 AI
		if newRole == "admin" {
			_ = store.UpdateUserAiEnabled(req.UserID, true)
		}
		c.JSON(http.StatusOK, gin.H{"success": true})

	case "updateAiEnabled":
		if currentUser.Role != "admin" {
			c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
			return
		}
		if req.UserID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "userId is required"})
			return
		}
		if err := store.UpdateUserAiEnabled(req.UserID, req.AiEnabled); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update AI access"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"success": true})

	case "resetTotp":
		if currentUser.Role != "admin" {
			c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
			return
		}
		if req.UserID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "userId is required"})
			return
		}
		if err := store.UpdateUserTotpEnabled(req.UserID, false); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reset two-factor authentication"})
			return
		}
		if err := store.UpdateUserTotpSecret(req.UserID, ""); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reset two-factor authentication"})
			return
		}
		if err := store.DeleteTOTPRecoveryCodesByUser(req.UserID); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reset two-factor authentication"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"success": true})

	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid action"})
	}
}

// DeleteUserHandler handles DELETE /api/auth/users (admin only)
func (h *AuthHandler) DeleteUserHandler(c *gin.Context) {
	currentUser := middleware.GetCurrentUser(c)
	if currentUser == nil || currentUser.Role != "admin" {
		c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
		return
	}

	var req struct {
		UserID string `json:"userId"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if req.UserID == currentUser.ID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot delete yourself"})
		return
	}

	if err := store.DeleteUser(req.UserID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete user"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}

// CreateUserByAdmin handles POST /api/auth/users (admin only)
// 管理员直接创建用户（用于邀请模式或关闭注册模式下添加用户）
func (h *AuthHandler) CreateUserByAdmin(c *gin.Context) {
	currentUser := middleware.GetCurrentUser(c)
	if currentUser == nil || currentUser.Role != "admin" {
		c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
		return
	}

	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
		Nickname string `json:"nickname"`
		Role     string `json:"role"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if req.Username == "" || req.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Username and password are required"})
		return
	}
	if len(req.Username) < 3 || len(req.Username) > 32 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Username must be 3-32 characters"})
		return
	}
	if len(req.Password) < 6 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Password must be at least 6 characters"})
		return
	}

	existing, err := store.GetUserByUsername(req.Username)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	if existing != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Username already exists"})
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), 10)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	role := "user"
	if req.Role == "admin" || req.Role == "user" {
		role = req.Role
	}

	nickname := req.Nickname
	if nickname == "" {
		nickname = req.Username
	}

	user := &model.User{
		ID:        uuid.New().String(),
		Username:  req.Username,
		Password:  string(hashedPassword),
		Nickname:  nickname,
		Role:      role,
		AiEnabled: role == "admin",
	}

	if err := store.CreateUser(user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to create user"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"user":    authUserPayload(user),
	})
}
