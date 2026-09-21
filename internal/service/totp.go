package service

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"math/big"
	"strings"
	"time"

	"github.com/pquerna/otp"
	"github.com/pquerna/otp/totp"

	"github.com/nowen-reader/nowen-reader/internal/config"
)

// TOTP parameters are fixed so provisioning URIs and validation stay compatible
// with the standard authenticator apps (Google Authenticator, Aegis, 1Password).
const (
	totpIssuerSecretSize = 20 // 160-bit shared secret
	totpPeriod           = 30 // seconds
	totpSkew             = 1  // accept the previous and next step (±30s clock drift)
)

// recoveryCodeGroups and recoveryCodeGroupLen define the human-friendly
// XXXX-XXXX shape of a recovery code.
const (
	recoveryCodeGroups   = 2
	recoveryCodeGroupLen = 4
)

// recoveryCodeAlphabet is Crockford-style base32 without visually ambiguous
// characters (no I, L, O, U, 0, 1) so a printed backup code stays transcribable.
const recoveryCodeAlphabet = "23456789ABCDEFGHJKMNPQRSTVWXYZ"

// GenerateTOTP creates a new TOTP shared secret and its otpauth:// provisioning
// URI. issuer defaults to the configured TOTP issuer when empty; accountName is
// the username shown inside the authenticator app.
func GenerateTOTP(accountName, issuer string) (secret string, otpauthURL string, err error) {
	if strings.TrimSpace(issuer) == "" {
		issuer = config.GetTOTP().Issuer
	}
	key, err := totp.Generate(totp.GenerateOpts{
		Issuer:      issuer,
		AccountName: accountName,
		Period:      totpPeriod,
		SecretSize:  totpIssuerSecretSize,
		Digits:      otp.DigitsSix,
		Algorithm:   otp.AlgorithmSHA1,
	})
	if err != nil {
		return "", "", err
	}
	return key.Secret(), key.URL(), nil
}

// ValidateTOTP reports whether code is valid for secret, accepting the current
// step plus the previous and next one (±1 window for clock drift). Empty codes
// or secrets are always rejected.
func ValidateTOTP(secret, code string) bool {
	secret = strings.TrimSpace(secret)
	code = strings.TrimSpace(code)
	if secret == "" || code == "" {
		return false
	}
	valid, err := totp.ValidateCustom(code, secret, time.Now(), totp.ValidateOpts{
		Period:    totpPeriod,
		Skew:      totpSkew,
		Digits:    otp.DigitsSix,
		Algorithm: otp.AlgorithmSHA1,
	})
	return err == nil && valid
}

// GenerateRecoveryCodes returns n random human-friendly recovery codes in the
// XXXX-XXXX shape. The plaintext codes are returned once; callers must persist
// only HashRecoveryCode(code).
func GenerateRecoveryCodes(n int) ([]string, error) {
	if n <= 0 {
		return []string{}, nil
	}
	codes := make([]string, 0, n)
	for i := 0; i < n; i++ {
		code, err := generateRecoveryCode()
		if err != nil {
			return nil, err
		}
		codes = append(codes, code)
	}
	return codes, nil
}

// generateRecoveryCode mints one XXXX-XXXX code from crypto/rand.
func generateRecoveryCode() (string, error) {
	alphabetLen := big.NewInt(int64(len(recoveryCodeAlphabet)))
	groups := make([]string, 0, recoveryCodeGroups)
	for g := 0; g < recoveryCodeGroups; g++ {
		var group strings.Builder
		group.Grow(recoveryCodeGroupLen)
		for i := 0; i < recoveryCodeGroupLen; i++ {
			idx, err := rand.Int(rand.Reader, alphabetLen)
			if err != nil {
				return "", err
			}
			group.WriteByte(recoveryCodeAlphabet[idx.Int64()])
		}
		groups = append(groups, group.String())
	}
	return strings.Join(groups, "-"), nil
}

// NormalizeRecoveryCode canonicalizes a user-supplied recovery code so that
// lookups are insensitive to case, dashes and surrounding whitespace.
func NormalizeRecoveryCode(code string) string {
	var b strings.Builder
	b.Grow(len(code))
	for _, r := range strings.ToUpper(code) {
		if r == '-' || r == ' ' {
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}

// HashRecoveryCode returns the SHA-256 hex digest of the normalized code,
// mirroring hashEmailCode. Only this hash is ever persisted.
func HashRecoveryCode(code string) string {
	digest := sha256.Sum256([]byte(NormalizeRecoveryCode(code)))
	return hex.EncodeToString(digest[:])
}
