package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/nowen-reader/nowen-reader/internal/middleware"
)

func registerAuthRoutes(api *gin.RouterGroup) {
	// Auth routes (Phase 1)
	// ============================================================
	auth := NewAuthHandler()
	apiKeys := NewAPIKeyHandler()
	email := NewEmailHandler()
	authConfig := NewAuthConfigHandler()
	totp := NewTOTPHandler()
	oidc := NewOIDCHandler()

	authGroup := api.Group("/auth")
	{
		// Login/register use strict rate limiting to prevent brute-force
		authGroup.POST("/register", middleware.RateLimitAuth(), auth.Register)
		authGroup.POST("/login", middleware.RateLimitAuth(), auth.Login)
		// Email verification / email-code login (Phase 1)
		authGroup.POST("/email/send", middleware.RateLimitAuth(), email.SendCode)
		authGroup.POST("/email/verify", middleware.RateLimitAuth(), email.VerifyCode)
		authGroup.POST("/email/login", middleware.RateLimitAuth(), email.LoginWithCode)
		// TOTP two-factor enrollment (session required) and login step-up (challenge-based)
		authGroup.POST("/totp/setup", middleware.SessionRequired(), totp.Setup)
		authGroup.POST("/totp/enable", middleware.SessionRequired(), totp.Enable)
		authGroup.POST("/totp/disable", middleware.SessionRequired(), totp.Disable)
		authGroup.GET("/totp/status", middleware.SessionRequired(), totp.Status)
		authGroup.POST("/totp/verify", middleware.RateLimitAuth(), totp.Verify)
		// OIDC single sign-on (Phase 3). The callback MUST stay unauthenticated:
		// the browser arrives there directly from the provider.
		authGroup.GET("/oidc/providers", oidc.Providers)
		authGroup.GET("/oidc/login", middleware.RateLimitAuth(), oidc.Login)
		authGroup.GET("/oidc/link", middleware.SessionRequired(), middleware.RateLimitAuth(), oidc.Link)
		authGroup.GET("/oidc/callback", oidc.Callback)
		authGroup.GET("/oidc/identities", middleware.SessionRequired(), oidc.Identities)
		authGroup.DELETE("/oidc/identities/:id", middleware.SessionRequired(), oidc.Unbind)
		// Logout and session check don't need strict limiting
		authGroup.POST("/logout", auth.Logout)
		authGroup.GET("/me", auth.Me)
	}

	usersGroup := api.Group("/auth/users")
	usersGroup.Use(middleware.AdminRequired())
	{
		usersGroup.GET("", auth.ListUsers)
		usersGroup.POST("", auth.CreateUserByAdmin)
		usersGroup.PUT("", auth.UpdateUser)
		usersGroup.DELETE("", auth.DeleteUserHandler)
	}

	apiKeyGroup := api.Group("/auth/api-keys")
	apiKeyGroup.Use(middleware.SessionRequired())
	{
		apiKeyGroup.GET("", apiKeys.List)
		apiKeyGroup.POST("", middleware.RateLimitAuth(), apiKeys.Create)
		apiKeyGroup.DELETE("/:id", apiKeys.Revoke)
		apiKeyGroup.DELETE("", middleware.RateLimitAuth(), apiKeys.RevokeAll)
	}

	adminAPIKeyGroup := api.Group("/admin/users/:id/api-keys")
	adminAPIKeyGroup.Use(middleware.SessionRequired(), middleware.AdminRequired())
	{
		adminAPIKeyGroup.GET("", apiKeys.AdminList)
		adminAPIKeyGroup.DELETE("", apiKeys.AdminRevokeAll)
	}

	adminAuthConfig := api.Group("/admin/auth-config")
	adminAuthConfig.Use(middleware.AdminRequired())
	{
		adminAuthConfig.GET("", authConfig.Get)
		adminAuthConfig.PUT("", authConfig.Update)
		adminAuthConfig.POST("/smtp-test", authConfig.SMTPTest)
	}

}
