// allow: SIZE_OK — single cohesive auth-security store (EmailToken,
// TOTPRecoveryCode, OIDCIdentity, AuthChallenge + user email/TOTP state),
// required as one CRUD file by the auth features task.
package store

import (
	"database/sql"
	"time"

	"github.com/nowen-reader/nowen-reader/internal/model"
)

// ============================================================
// User email / TOTP state
// ============================================================

// GetUserByEmail finds a user by their (non-empty) email address.
// Returns nil, nil if no user has that email.
func GetUserByEmail(email string) (*model.User, error) {
	user := &model.User{}
	err := db.QueryRow(
		`SELECT "id", "username", "password", "nickname", "role", "aiEnabled", "email", "emailVerified", "totpSecret", "totpEnabled", "createdAt", "updatedAt"
		 FROM "User" WHERE "email" = ? AND "email" != '' LIMIT 1`,
		email,
	).Scan(&user.ID, &user.Username, &user.Password, &user.Nickname, &user.Role, &user.AiEnabled,
		&user.Email, &user.EmailVerified, &user.TotpSecret, &user.TotpEnabled, &user.CreatedAt, &user.UpdatedAt)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	return user, err
}

// UpdateUserEmail sets a user's email address and its verification flag.
func UpdateUserEmail(userID, email string, verified bool) error {
	_, err := db.Exec(
		`UPDATE "User" SET "email" = ?, "emailVerified" = ?, "updatedAt" = ? WHERE "id" = ?`,
		email, verified, time.Now(), userID,
	)
	return err
}

// UpdateUserEmailVerified toggles a user's email verification flag.
func UpdateUserEmailVerified(userID string, verified bool) error {
	_, err := db.Exec(
		`UPDATE "User" SET "emailVerified" = ?, "updatedAt" = ? WHERE "id" = ?`,
		verified, time.Now(), userID,
	)
	return err
}

// UpdateUserTotpSecret stores a user's TOTP shared secret.
func UpdateUserTotpSecret(userID, secret string) error {
	_, err := db.Exec(
		`UPDATE "User" SET "totpSecret" = ?, "updatedAt" = ? WHERE "id" = ?`,
		secret, time.Now(), userID,
	)
	return err
}

// UpdateUserTotpEnabled toggles TOTP two-factor authentication for a user.
func UpdateUserTotpEnabled(userID string, enabled bool) error {
	_, err := db.Exec(
		`UPDATE "User" SET "totpEnabled" = ?, "updatedAt" = ? WHERE "id" = ?`,
		enabled, time.Now(), userID,
	)
	return err
}

// ============================================================
// EmailToken operations
// ============================================================

const emailTokenColumns = `"id", "userId", "email", "purpose", "codeHash", "expiresAt", "consumedAt", "attempts", "createdAt"`

func scanEmailToken(scanner interface{ Scan(dest ...any) error }) (*model.EmailToken, error) {
	token := &model.EmailToken{}
	var consumedAt sql.NullTime
	if err := scanner.Scan(
		&token.ID, &token.UserID, &token.Email, &token.Purpose, &token.CodeHash,
		&token.ExpiresAt, &consumedAt, &token.Attempts, &token.CreatedAt,
	); err != nil {
		return nil, err
	}
	if consumedAt.Valid {
		token.ConsumedAt = &consumedAt.Time
	}
	return token, nil
}

// CreateEmailToken inserts a new email verification/login token.
func CreateEmailToken(token *model.EmailToken) error {
	if token.CreatedAt.IsZero() {
		token.CreatedAt = time.Now()
	}
	_, err := db.Exec(
		`INSERT INTO "EmailToken" ("id", "userId", "email", "purpose", "codeHash", "expiresAt", "consumedAt", "attempts", "createdAt")
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		token.ID, token.UserID, token.Email, token.Purpose, token.CodeHash,
		token.ExpiresAt, token.ConsumedAt, token.Attempts, token.CreatedAt,
	)
	return err
}

// GetActiveEmailToken returns the most recent unconsumed, unexpired token for
// the given email and purpose. Returns nil, nil if none is active.
func GetActiveEmailToken(email, purpose string) (*model.EmailToken, error) {
	token, err := scanEmailToken(db.QueryRow(
		`SELECT `+emailTokenColumns+`
		 FROM "EmailToken"
		 WHERE "email" = ? AND "purpose" = ? AND "consumedAt" IS NULL AND "expiresAt" > ?
		 ORDER BY "createdAt" DESC LIMIT 1`,
		email, purpose, time.Now(),
	))
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return token, err
}

// ConsumeEmailToken marks a token as consumed (idempotent for already-consumed rows).
func ConsumeEmailToken(id string) error {
	_, err := db.Exec(
		`UPDATE "EmailToken" SET "consumedAt" = ? WHERE "id" = ? AND "consumedAt" IS NULL`,
		time.Now(), id,
	)
	return err
}

// IncrementEmailTokenAttempts increments the failed-attempt counter for a token.
func IncrementEmailTokenAttempts(id string) error {
	_, err := db.Exec(
		`UPDATE "EmailToken" SET "attempts" = "attempts" + 1 WHERE "id" = ?`,
		id,
	)
	return err
}

// DeleteExpiredEmailTokens removes expired tokens. Returns the number deleted.
func DeleteExpiredEmailTokens() (int64, error) {
	var rowsAffected int64
	err := runSerializedDBWrite("email-token-cleanup", func() error {
		result, err := db.Exec(`DELETE FROM "EmailToken" WHERE "expiresAt" < ?`, time.Now())
		if err != nil {
			return err
		}
		rowsAffected, err = result.RowsAffected()
		return err
	})
	return rowsAffected, err
}

// ============================================================
// TOTPRecoveryCode operations
// ============================================================

// CreateTOTPRecoveryCodes inserts a batch of recovery codes in a single transaction.
func CreateTOTPRecoveryCodes(codes []*model.TOTPRecoveryCode) error {
	if len(codes) == 0 {
		return nil
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	now := time.Now()
	for _, code := range codes {
		if code.CreatedAt.IsZero() {
			code.CreatedAt = now
		}
		if _, err := tx.Exec(
			`INSERT INTO "TOTPRecoveryCode" ("id", "userId", "codeHash", "usedAt", "createdAt")
			 VALUES (?, ?, ?, ?, ?)`,
			code.ID, code.UserID, code.CodeHash, code.UsedAt, code.CreatedAt,
		); err != nil {
			return err
		}
	}
	return tx.Commit()
}

// GetUnusedRecoveryCode finds an unused recovery code for a user by its hash.
// Returns nil, nil if no matching unused code exists.
func GetUnusedRecoveryCode(userID, codeHash string) (*model.TOTPRecoveryCode, error) {
	code := &model.TOTPRecoveryCode{}
	var usedAt sql.NullTime
	err := db.QueryRow(
		`SELECT "id", "userId", "codeHash", "usedAt", "createdAt"
		 FROM "TOTPRecoveryCode"
		 WHERE "userId" = ? AND "codeHash" = ? AND "usedAt" IS NULL LIMIT 1`,
		userID, codeHash,
	).Scan(&code.ID, &code.UserID, &code.CodeHash, &usedAt, &code.CreatedAt)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if usedAt.Valid {
		code.UsedAt = &usedAt.Time
	}
	return code, nil
}

// MarkRecoveryCodeUsed marks a recovery code as consumed.
func MarkRecoveryCodeUsed(id string) error {
	_, err := db.Exec(
		`UPDATE "TOTPRecoveryCode" SET "usedAt" = ? WHERE "id" = ? AND "usedAt" IS NULL`,
		time.Now(), id,
	)
	return err
}

// DeleteTOTPRecoveryCodesByUser removes all recovery codes for a user.
func DeleteTOTPRecoveryCodesByUser(userID string) error {
	_, err := db.Exec(`DELETE FROM "TOTPRecoveryCode" WHERE "userId" = ?`, userID)
	return err
}

// ============================================================
// OIDCIdentity operations
// ============================================================

// GetOIDCIdentity finds an identity by its issuer + subject pair.
// Returns nil, nil if not found.
func GetOIDCIdentity(issuer, subject string) (*model.OIDCIdentity, error) {
	identity := &model.OIDCIdentity{}
	err := db.QueryRow(
		`SELECT "id", "userId", "issuer", "subject", "email", "createdAt", "updatedAt"
		 FROM "OIDCIdentity" WHERE "issuer" = ? AND "subject" = ? LIMIT 1`,
		issuer, subject,
	).Scan(&identity.ID, &identity.UserID, &identity.Issuer, &identity.Subject,
		&identity.Email, &identity.CreatedAt, &identity.UpdatedAt)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	return identity, err
}

// CreateOIDCIdentity links an external OIDC identity to a local user.
func CreateOIDCIdentity(identity *model.OIDCIdentity) error {
	now := time.Now()
	identity.CreatedAt = now
	identity.UpdatedAt = now
	_, err := db.Exec(
		`INSERT INTO "OIDCIdentity" ("id", "userId", "issuer", "subject", "email", "createdAt", "updatedAt")
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		identity.ID, identity.UserID, identity.Issuer, identity.Subject,
		identity.Email, identity.CreatedAt, identity.UpdatedAt,
	)
	return err
}

// ListOIDCIdentitiesByUser returns all OIDC identities linked to a user.
func ListOIDCIdentitiesByUser(userID string) ([]model.OIDCIdentity, error) {
	rows, err := db.Query(
		`SELECT "id", "userId", "issuer", "subject", "email", "createdAt", "updatedAt"
		 FROM "OIDCIdentity" WHERE "userId" = ? ORDER BY "createdAt" ASC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	identities := make([]model.OIDCIdentity, 0)
	for rows.Next() {
		var identity model.OIDCIdentity
		if err := rows.Scan(&identity.ID, &identity.UserID, &identity.Issuer, &identity.Subject,
			&identity.Email, &identity.CreatedAt, &identity.UpdatedAt); err != nil {
			return nil, err
		}
		identities = append(identities, identity)
	}
	return identities, rows.Err()
}

// DeleteOIDCIdentity unlinks an external OIDC identity.
func DeleteOIDCIdentity(id string) error {
	_, err := db.Exec(`DELETE FROM "OIDCIdentity" WHERE "id" = ?`, id)
	return err
}

// ============================================================
// AuthChallenge operations
// ============================================================

// CreateAuthChallenge inserts a short-lived multi-step authentication challenge.
func CreateAuthChallenge(challenge *model.AuthChallenge) error {
	if challenge.CreatedAt.IsZero() {
		challenge.CreatedAt = time.Now()
	}
	_, err := db.Exec(
		`INSERT INTO "AuthChallenge" ("id", "userId", "purpose", "expiresAt", "consumedAt", "createdAt")
		 VALUES (?, ?, ?, ?, ?, ?)`,
		challenge.ID, challenge.UserID, challenge.Purpose, challenge.ExpiresAt,
		challenge.ConsumedAt, challenge.CreatedAt,
	)
	return err
}

// GetActiveAuthChallenge returns an unconsumed, unexpired challenge by ID.
// Returns nil, nil if none is active.
func GetActiveAuthChallenge(id string) (*model.AuthChallenge, error) {
	challenge := &model.AuthChallenge{}
	var consumedAt sql.NullTime
	err := db.QueryRow(
		`SELECT "id", "userId", "purpose", "expiresAt", "consumedAt", "createdAt"
		 FROM "AuthChallenge"
		 WHERE "id" = ? AND "consumedAt" IS NULL AND "expiresAt" > ? LIMIT 1`,
		id, time.Now(),
	).Scan(&challenge.ID, &challenge.UserID, &challenge.Purpose, &challenge.ExpiresAt,
		&consumedAt, &challenge.CreatedAt)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if consumedAt.Valid {
		challenge.ConsumedAt = &consumedAt.Time
	}
	return challenge, nil
}

// ConsumeAuthChallenge marks a challenge as consumed.
func ConsumeAuthChallenge(id string) error {
	_, err := db.Exec(
		`UPDATE "AuthChallenge" SET "consumedAt" = ? WHERE "id" = ? AND "consumedAt" IS NULL`,
		time.Now(), id,
	)
	return err
}

// DeleteExpiredAuthChallenges removes expired challenges. Returns the number deleted.
func DeleteExpiredAuthChallenges() (int64, error) {
	var rowsAffected int64
	err := runSerializedDBWrite("auth-challenge-cleanup", func() error {
		result, err := db.Exec(`DELETE FROM "AuthChallenge" WHERE "expiresAt" < ?`, time.Now())
		if err != nil {
			return err
		}
		rowsAffected, err = result.RowsAffected()
		return err
	})
	return rowsAffected, err
}
