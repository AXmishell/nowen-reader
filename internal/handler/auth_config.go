package handler

import (
	"net/http"
	"net/mail"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/nowen-reader/nowen-reader/internal/config"
	"github.com/nowen-reader/nowen-reader/internal/middleware"
	"github.com/nowen-reader/nowen-reader/internal/service"
)

// AuthConfigHandler manages the SMTP / email-authentication configuration.
type AuthConfigHandler struct{}

// NewAuthConfigHandler creates a new AuthConfigHandler.
func NewAuthConfigHandler() *AuthConfigHandler {
	return &AuthConfigHandler{}
}

// absoluteCallbackURL turns a base-path-relative URL into an absolute one using
// the current request's scheme and host, so the admin can copy it straight into
// the identity provider's redirect-URI allowlist (a bare path is rejected by
// most providers). An already-absolute URL, or a request without a Host header,
// is returned unchanged.
func absoluteCallbackURL(c *gin.Context, path string) string {
	if strings.HasPrefix(path, "http://") || strings.HasPrefix(path, "https://") {
		return path
	}

	host := c.Request.Host
	if config.TrustProxyHeaders() {
		if forwarded := c.GetHeader("X-Forwarded-Host"); forwarded != "" {
			// X-Forwarded-Host may be a comma-separated chain; the client-facing
			// host is the first entry.
			host = strings.TrimSpace(strings.Split(forwarded, ",")[0])
		}
	}
	if host == "" {
		return path
	}

	scheme := "http"
	if middleware.IsRequestSecure(c) {
		scheme = "https"
	}
	return scheme + "://" + host + path
}

// Get handles GET /api/admin/auth-config. The SMTP password is never returned;
// passwordSet reports whether one is stored.
func (h *AuthConfigHandler) Get(c *gin.Context) {
	smtp := config.GetSMTP()
	totp := config.GetTOTP()
	oidc := config.GetOIDC()
	c.JSON(http.StatusOK, gin.H{
		"smtp": gin.H{
			"enabled":     config.IsSMTPEnabled(),
			"host":        smtp.Host,
			"port":        smtp.Port,
			"username":    smtp.Username,
			"passwordSet": smtp.Password != "",
			"from":        smtp.From,
			"fromName":    smtp.FromName,
			"tlsMode":     smtp.TLSMode,
		},
		"totp": gin.H{
			"enabled":           config.IsTOTPEnabled(),
			"requiredForAdmins": totp.RequiredForAdmins,
			"issuer":            totp.Issuer,
		},
		"oidc": gin.H{
			"enabled":         config.IsOIDCEnabled(),
			"issuerUrl":       oidc.IssuerURL,
			"clientId":        oidc.ClientID,
			"clientSecretSet": oidc.ClientSecret != "",
			"scopes":          oidc.Scopes,
			"buttonLabel":     oidc.ButtonLabel,
			"autoCreateUsers": oidc.AutoCreateUsers,
			"callbackUrl":     absoluteCallbackURL(c, service.OIDCCallbackURL()),
		},
		"emailVerificationRequired": config.IsEmailVerificationRequired(),
		"emailCodeLoginEnabled":     config.IsEmailCodeLoginEnabled(),
	})
}

// Update handles PUT /api/admin/auth-config. Pointer fields are merged onto a
// copy of the current config; an omitted or empty password keeps the existing
// one. Secrets are never echoed back.
func (h *AuthConfigHandler) Update(c *gin.Context) {
	var body struct {
		SMTP *struct {
			Enabled  *bool   `json:"enabled"`
			Host     *string `json:"host"`
			Port     *int    `json:"port"`
			Username *string `json:"username"`
			Password *string `json:"password"`
			From     *string `json:"from"`
			FromName *string `json:"fromName"`
			TLSMode  *string `json:"tlsMode"`
		} `json:"smtp"`
		TOTP *struct {
			Enabled           *bool   `json:"enabled"`
			RequiredForAdmins *bool   `json:"requiredForAdmins"`
			Issuer            *string `json:"issuer"`
		} `json:"totp"`
		OIDC *struct {
			Enabled         *bool   `json:"enabled"`
			IssuerURL       *string `json:"issuerUrl"`
			ClientID        *string `json:"clientId"`
			ClientSecret    *string `json:"clientSecret"`
			Scopes          *string `json:"scopes"`
			ButtonLabel     *string `json:"buttonLabel"`
			AutoCreateUsers *bool   `json:"autoCreateUsers"`
		} `json:"oidc"`
		EmailVerificationRequired *bool `json:"emailVerificationRequired"`
		EmailCodeLoginEnabled     *bool `json:"emailCodeLoginEnabled"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	current := config.GetSiteConfig()

	if body.SMTP != nil {
		smtp := config.SMTPConfig{}
		if current.SMTP != nil {
			smtp = *current.SMTP
		}
		if body.SMTP.Host != nil {
			smtp.Host = strings.TrimSpace(*body.SMTP.Host)
		}
		if body.SMTP.Port != nil {
			if *body.SMTP.Port <= 0 || *body.SMTP.Port > 65535 {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid SMTP port"})
				return
			}
			smtp.Port = *body.SMTP.Port
		}
		if body.SMTP.Username != nil {
			smtp.Username = strings.TrimSpace(*body.SMTP.Username)
		}
		if body.SMTP.Password != nil && *body.SMTP.Password != "" {
			smtp.Password = *body.SMTP.Password
		}
		if body.SMTP.From != nil {
			smtp.From = strings.TrimSpace(*body.SMTP.From)
		}
		if body.SMTP.FromName != nil {
			smtp.FromName = strings.TrimSpace(*body.SMTP.FromName)
		}
		if body.SMTP.TLSMode != nil {
			mode := strings.ToLower(strings.TrimSpace(*body.SMTP.TLSMode))
			switch mode {
			case "none", "starttls", "ssl":
				smtp.TLSMode = mode
			default:
				c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid tlsMode, must be none, starttls or ssl"})
				return
			}
		}
		current.SMTP = &smtp
		if body.SMTP.Enabled != nil {
			current.SMTPEnabled = body.SMTP.Enabled
		}
	}

	if body.TOTP != nil {
		totp := config.TOTPConfig{}
		if current.TOTP != nil {
			totp = *current.TOTP
		}
		if body.TOTP.Enabled != nil {
			totp.Enabled = body.TOTP.Enabled
		}
		if body.TOTP.RequiredForAdmins != nil {
			totp.RequiredForAdmins = *body.TOTP.RequiredForAdmins
		}
		if body.TOTP.Issuer != nil {
			// An empty issuer keeps the current value (GetTOTP falls back to the
			// default at read time, so no secret or default is ever leaked here).
			if issuer := strings.TrimSpace(*body.TOTP.Issuer); issuer != "" {
				totp.Issuer = issuer
			}
		}
		current.TOTP = &totp
	}

	if body.OIDC != nil {
		oidc := config.OIDCConfig{}
		if current.OIDC != nil {
			oidc = *current.OIDC
		}
		if body.OIDC.Enabled != nil {
			oidc.Enabled = body.OIDC.Enabled
		}
		if body.OIDC.IssuerURL != nil {
			oidc.IssuerURL = strings.TrimSpace(*body.OIDC.IssuerURL)
		}
		if body.OIDC.ClientID != nil {
			oidc.ClientID = strings.TrimSpace(*body.OIDC.ClientID)
		}
		// An empty/omitted secret keeps the stored one, matching the SMTP
		// password precedent; the secret is never echoed back.
		if body.OIDC.ClientSecret != nil && *body.OIDC.ClientSecret != "" {
			oidc.ClientSecret = *body.OIDC.ClientSecret
		}
		if body.OIDC.Scopes != nil {
			oidc.Scopes = strings.TrimSpace(*body.OIDC.Scopes)
		}
		if body.OIDC.ButtonLabel != nil {
			oidc.ButtonLabel = strings.TrimSpace(*body.OIDC.ButtonLabel)
		}
		if body.OIDC.AutoCreateUsers != nil {
			oidc.AutoCreateUsers = *body.OIDC.AutoCreateUsers
		}
		current.OIDC = &oidc
	}

	// Enabling OIDC requires a usable issuer and client id.
	if current.OIDC != nil && current.OIDC.Enabled != nil && *current.OIDC.Enabled {
		if strings.TrimSpace(current.OIDC.IssuerURL) == "" || strings.TrimSpace(current.OIDC.ClientID) == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "OIDC issuerUrl and clientId are required when enabled"})
			return
		}
	}

	if body.EmailVerificationRequired != nil {
		current.EmailVerificationRequired = body.EmailVerificationRequired
	}
	if body.EmailCodeLoginEnabled != nil {
		current.EmailCodeLoginEnabled = body.EmailCodeLoginEnabled
	}

	if err := config.SaveSiteConfig(&current); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save auth config"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// SMTPTest handles POST /api/admin/auth-config/smtp-test.
func (h *AuthConfigHandler) SMTPTest(c *gin.Context) {
	var body struct {
		To string `json:"to"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}
	to := strings.TrimSpace(body.To)
	if _, err := mail.ParseAddress(to); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid email address"})
		return
	}
	if !service.IsConfigured() {
		c.JSON(http.StatusBadRequest, gin.H{"error": "SMTP 未配置"})
		return
	}
	if err := service.SendTestEmail(to); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}
