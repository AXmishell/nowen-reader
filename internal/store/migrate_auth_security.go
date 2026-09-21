package store

import "strings"

func init() {
	Migrations = append(Migrations, Migration{
		Version:     44,
		Description: "Add auth security: user email/TOTP fields, email tokens, recovery codes, OIDC identities, auth challenges",
		SQL: strings.Join([]string{
			// User: email + TOTP columns.
			`ALTER TABLE "User" ADD COLUMN "email" TEXT NOT NULL DEFAULT '';`,
			`ALTER TABLE "User" ADD COLUMN "emailVerified" BOOLEAN NOT NULL DEFAULT 0;`,
			`ALTER TABLE "User" ADD COLUMN "totpSecret" TEXT NOT NULL DEFAULT '';`,
			`ALTER TABLE "User" ADD COLUMN "totpEnabled" BOOLEAN NOT NULL DEFAULT 0;`,
			`CREATE UNIQUE INDEX IF NOT EXISTS "User_email_key" ON "User"("email") WHERE "email" != '';`,

			// EmailToken: one-time verification/login codes.
			`CREATE TABLE IF NOT EXISTS "EmailToken" (
				"id"         TEXT NOT NULL PRIMARY KEY,
				"userId"     TEXT NOT NULL,
				"email"      TEXT NOT NULL,
				"purpose"    TEXT NOT NULL,
				"codeHash"   TEXT NOT NULL,
				"expiresAt"  DATETIME NOT NULL,
				"consumedAt" DATETIME,
				"attempts"   INTEGER NOT NULL DEFAULT 0,
				"createdAt"  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
				CONSTRAINT "EmailToken_userId_fkey" FOREIGN KEY ("userId")
					REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
			);`,
			`CREATE INDEX IF NOT EXISTS "EmailToken_userId_idx" ON "EmailToken"("userId");`,
			`CREATE INDEX IF NOT EXISTS "EmailToken_email_idx" ON "EmailToken"("email");`,
			`CREATE INDEX IF NOT EXISTS "EmailToken_expiresAt_idx" ON "EmailToken"("expiresAt");`,

			// TOTPRecoveryCode: single-use fallback codes for TOTP 2FA.
			`CREATE TABLE IF NOT EXISTS "TOTPRecoveryCode" (
				"id"        TEXT NOT NULL PRIMARY KEY,
				"userId"    TEXT NOT NULL,
				"codeHash"  TEXT NOT NULL,
				"usedAt"    DATETIME,
				"createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
				CONSTRAINT "TOTPRecoveryCode_userId_fkey" FOREIGN KEY ("userId")
					REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
			);`,
			`CREATE UNIQUE INDEX IF NOT EXISTS "TOTPRecoveryCode_codeHash_key" ON "TOTPRecoveryCode"("codeHash");`,
			`CREATE INDEX IF NOT EXISTS "TOTPRecoveryCode_userId_idx" ON "TOTPRecoveryCode"("userId");`,

			// OIDCIdentity: external issuer + subject linked to a local user.
			`CREATE TABLE IF NOT EXISTS "OIDCIdentity" (
				"id"        TEXT NOT NULL PRIMARY KEY,
				"userId"    TEXT NOT NULL,
				"issuer"    TEXT NOT NULL,
				"subject"   TEXT NOT NULL,
				"email"     TEXT NOT NULL DEFAULT '',
				"createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
				"updatedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
				CONSTRAINT "OIDCIdentity_userId_fkey" FOREIGN KEY ("userId")
					REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
			);`,
			`CREATE UNIQUE INDEX IF NOT EXISTS "OIDCIdentity_issuer_subject_key" ON "OIDCIdentity"("issuer", "subject");`,
			`CREATE INDEX IF NOT EXISTS "OIDCIdentity_userId_idx" ON "OIDCIdentity"("userId");`,

			// AuthChallenge: short-lived server-side multi-step auth challenge.
			`CREATE TABLE IF NOT EXISTS "AuthChallenge" (
				"id"         TEXT NOT NULL PRIMARY KEY,
				"userId"     TEXT NOT NULL,
				"purpose"    TEXT NOT NULL,
				"expiresAt"  DATETIME NOT NULL,
				"consumedAt" DATETIME,
				"createdAt"  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
				CONSTRAINT "AuthChallenge_userId_fkey" FOREIGN KEY ("userId")
					REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
			);`,
			`CREATE INDEX IF NOT EXISTS "AuthChallenge_userId_idx" ON "AuthChallenge"("userId");`,
			`CREATE INDEX IF NOT EXISTS "AuthChallenge_expiresAt_idx" ON "AuthChallenge"("expiresAt");`,
		}, "\n"),
	})
}
