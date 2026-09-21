package handler

import (
	"errors"
	"strings"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"github.com/nowen-reader/nowen-reader/internal/config"
	"github.com/nowen-reader/nowen-reader/internal/model"
	"github.com/nowen-reader/nowen-reader/internal/store"
)

// Username bounds copied from the registration rules.
const (
	oidcUsernameMinLen = 3
	oidcUsernameMaxLen = 32
)

// linkIdentity attaches an external identity to an existing local user. It
// returns a non-empty short error code on failure.
func (h *OIDCHandler) linkIdentity(issuer, subject, email, userID string) (*model.User, string) {
	existing, err := store.GetOIDCIdentity(issuer, subject)
	if err != nil {
		return nil, "internal"
	}
	if existing != nil {
		if existing.UserID != userID {
			return nil, "link_conflict"
		}
	} else {
		identity := &model.OIDCIdentity{
			ID:      uuid.New().String(),
			UserID:  userID,
			Issuer:  issuer,
			Subject: subject,
			Email:   email,
		}
		if err := store.CreateOIDCIdentity(identity); err != nil {
			return nil, "link_failed"
		}
	}

	user, err := store.GetUserByID(userID)
	if err != nil || user == nil {
		return nil, "internal"
	}
	return user, ""
}

// resolveIdentityUser maps a verified external identity to a local user. When
// the identity is unknown it auto-provisions a local account if configured,
// otherwise it reports that the account is not linked.
func (h *OIDCHandler) resolveIdentityUser(issuer, subject, email string, emailVerified bool, claims map[string]any) (*model.User, string) {
	identity, err := store.GetOIDCIdentity(issuer, subject)
	if err != nil {
		return nil, "internal"
	}
	if identity != nil {
		user, err := store.GetUserByID(identity.UserID)
		if err != nil || user == nil {
			return nil, "internal"
		}
		return user, ""
	}

	if !config.GetOIDC().AutoCreateUsers {
		return nil, "not_linked"
	}

	user, err := provisionOIDCUser(issuer, subject, email, emailVerified, claims)
	if err != nil {
		return nil, "provision_failed"
	}
	return user, ""
}

// provisionOIDCUser creates a local account for an unknown OIDC identity. The
// password is random and immediately hashed, so password login stays unusable
// until the user explicitly sets one.
func provisionOIDCUser(issuer, subject, email string, emailVerified bool, claims map[string]any) (*model.User, error) {
	username, err := uniqueOIDCUsername(
		oidcClaimString(claims, "preferred_username"),
		email,
		subject,
	)
	if err != nil {
		return nil, err
	}

	randomPassword, err := oidcRandomToken(32)
	if err != nil {
		return nil, err
	}
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(randomPassword), 10)
	if err != nil {
		return nil, err
	}

	nickname := oidcClaimString(claims, "name")
	if nickname == "" {
		nickname = username
	}

	user := &model.User{
		ID:        uuid.New().String(),
		Username:  username,
		Password:  string(hashedPassword),
		Nickname:  nickname,
		Role:      "user",
		AiEnabled: false,
	}
	// Bind the provider email only when it is not already owned by another
	// account, so an OIDC login can never take over an existing local account.
	if email != "" {
		existing, lookupErr := store.GetUserByEmail(email)
		if lookupErr != nil {
			return nil, lookupErr
		}
		if existing == nil {
			user.Email = email
			user.EmailVerified = emailVerified
		}
	}

	if err := store.CreateUser(user); err != nil {
		return nil, err
	}

	identity := &model.OIDCIdentity{
		ID:      uuid.New().String(),
		UserID:  user.ID,
		Issuer:  issuer,
		Subject: subject,
		Email:   email,
	}
	if err := store.CreateOIDCIdentity(identity); err != nil {
		// Remove the orphaned user so a later retry can provision cleanly.
		_ = store.DeleteUser(user.ID)
		return nil, err
	}
	return user, nil
}

// sanitizeOIDCUsername lowercases a candidate and keeps only characters that
// are safe inside a username, replacing everything else with "_".
func sanitizeOIDCUsername(raw string) string {
	raw = strings.ToLower(strings.TrimSpace(raw))
	var builder strings.Builder
	for _, r := range raw {
		switch {
		case r >= 'a' && r <= 'z', r >= '0' && r <= '9', r == '-', r == '_', r == '.':
			builder.WriteRune(r)
		default:
			builder.WriteRune('_')
		}
	}
	return strings.Trim(builder.String(), "._-")
}

// oidcEmailLocalPart returns the local part of an email address, or "".
func oidcEmailLocalPart(email string) string {
	at := strings.IndexByte(email, '@')
	if at <= 0 {
		return ""
	}
	return email[:at]
}

// fitOIDCUsername clamps a sanitized candidate into the registration length bounds.
func fitOIDCUsername(name string) string {
	if len(name) > oidcUsernameMaxLen {
		name = name[:oidcUsernameMaxLen]
	}
	for len(name) < oidcUsernameMinLen {
		name += "0"
	}
	return name
}

// uniqueOIDCUsername derives a free local username from the provider claims.
func uniqueOIDCUsername(preferred, email, subject string) (string, error) {
	base := sanitizeOIDCUsername(preferred)
	if base == "" {
		base = sanitizeOIDCUsername(oidcEmailLocalPart(email))
	}
	if base == "" {
		prefix := subject
		if len(prefix) > 8 {
			prefix = prefix[:8]
		}
		base = "oidc_" + sanitizeOIDCUsername(prefix)
	}
	base = fitOIDCUsername(base)

	candidate := base
	for attempt := 0; attempt < 10; attempt++ {
		existing, err := store.GetUserByUsername(candidate)
		if err != nil {
			return "", err
		}
		if existing == nil {
			return candidate, nil
		}
		suffix, err := oidcRandomToken(4)
		if err != nil {
			return "", err
		}
		trimmed := base
		if maxBase := oidcUsernameMaxLen - len(suffix) - 1; len(trimmed) > maxBase {
			trimmed = trimmed[:maxBase]
		}
		candidate = trimmed + "_" + suffix
	}
	return "", errors.New("oidc: could not allocate a unique username")
}
