// Package security 提供应用级密钥管理与对称加密工具。
//
// 本包仅依赖标准库与 internal/config，供 SMTP、TOTP、OIDC 等
// 需要"静态加密"的认证特性使用。密钥解析优先级：
//  1. 环境变量 NOWEN_SECRET_KEY —— base64 编码的 32 字节，或任意字符串（sha256 派生）；
//  2. DATA_DIR/secret.key —— 首次运行自动生成 32 字节随机密钥并落盘（0600）。
package security

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/nowen-reader/nowen-reader/internal/config"
)

var (
	keyOnce   sync.Once
	cachedKey []byte
	keyErr    error
)

// KeyFilePath 返回本地密钥文件的路径（DATA_DIR/secret.key）。
func KeyFilePath() string {
	return filepath.Join(config.DataDir(), "secret.key")
}

// resolveKey 惰性解析密钥并缓存；解析失败时后续调用会重复返回同一错误。
func resolveKey() ([]byte, error) {
	keyOnce.Do(func() {
		cachedKey, keyErr = loadOrCreateKey()
	})
	if keyErr != nil {
		return nil, keyErr
	}
	return cachedKey, nil
}

// loadOrCreateKey 按 env > 密钥文件 > 自动生成的顺序解析 32 字节密钥。
func loadOrCreateKey() ([]byte, error) {
	if raw := strings.TrimSpace(os.Getenv("NOWEN_SECRET_KEY")); raw != "" {
		if decoded, err := base64.StdEncoding.DecodeString(raw); err == nil && len(decoded) == 32 {
			return decoded, nil
		}
		sum := sha256.Sum256([]byte(raw))
		return sum[:], nil
	}

	path := KeyFilePath()
	data, err := os.ReadFile(path)
	switch {
	case err == nil:
		if len(data) == 32 {
			return data, nil
		}
		if decoded, decErr := base64.StdEncoding.DecodeString(strings.TrimSpace(string(data))); decErr == nil && len(decoded) == 32 {
			return decoded, nil
		}
		return nil, fmt.Errorf("security: key file %s must contain 32 raw bytes or base64-encoded 32 bytes", path)
	case errors.Is(err, os.ErrNotExist):
		// 继续向下生成新密钥。
	default:
		return nil, fmt.Errorf("security: read key file %s: %w", path, err)
	}

	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return nil, fmt.Errorf("security: generate key: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return nil, fmt.Errorf("security: create key dir: %w", err)
	}
	if err := os.WriteFile(path, key, 0600); err != nil {
		return nil, fmt.Errorf("security: write key file %s: %w", path, err)
	}
	return key, nil
}

// newGCM 使用当前密钥构造 AES-256-GCM AEAD。
func newGCM() (cipher.AEAD, error) {
	key, err := resolveKey()
	if err != nil {
		return nil, err
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("security: init cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("security: init gcm: %w", err)
	}
	return gcm, nil
}

// Encrypt 使用 AES-256-GCM 加密明文，返回 base64(nonce || ciphertext)。
// 空明文返回 ("", nil)。
func Encrypt(plaintext string) (string, error) {
	if plaintext == "" {
		return "", nil
	}
	gcm, err := newGCM()
	if err != nil {
		return "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return "", fmt.Errorf("security: read nonce: %w", err)
	}
	sealed := gcm.Seal(nonce, nonce, []byte(plaintext), nil)
	return base64.StdEncoding.EncodeToString(sealed), nil
}

// Decrypt 解密 Encrypt 产生的 base64 密文。
// 空输入返回 ("", nil)；格式错误或密文被篡改时返回描述性错误，绝不 panic。
func Decrypt(encoded string) (string, error) {
	if encoded == "" {
		return "", nil
	}
	data, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return "", fmt.Errorf("security: decode ciphertext: %w", err)
	}
	gcm, err := newGCM()
	if err != nil {
		return "", err
	}
	nonceSize := gcm.NonceSize()
	if len(data) < nonceSize {
		return "", fmt.Errorf("security: ciphertext too short: got %d bytes, need at least %d", len(data), nonceSize)
	}
	nonce, ciphertext := data[:nonceSize], data[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", fmt.Errorf("security: decrypt: %w", err)
	}
	return string(plaintext), nil
}
