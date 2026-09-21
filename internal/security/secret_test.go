package security

import (
	"encoding/base64"
	"os"
	"testing"
)

// TestMain 将所有测试隔离到临时 DATA_DIR，并确保走"密钥文件"而非环境变量路径。
func TestMain(m *testing.M) {
	dir, err := os.MkdirTemp("", "nowen-security-*")
	if err != nil {
		panic(err)
	}
	_ = os.Setenv("DATA_DIR", dir)
	_ = os.Unsetenv("NOWEN_SECRET_KEY")

	code := m.Run()
	_ = os.RemoveAll(dir)
	os.Exit(code)
}

func TestEncryptDecryptRoundtrip(t *testing.T) {
	plaintext := "s3cret-token-日本語-🔐"

	encrypted, err := Encrypt(plaintext)
	if err != nil {
		t.Fatalf("Encrypt() error = %v", err)
	}
	if encrypted == plaintext {
		t.Fatal("Encrypt() must not return plaintext")
	}

	decrypted, err := Decrypt(encrypted)
	if err != nil {
		t.Fatalf("Decrypt() error = %v", err)
	}
	if decrypted != plaintext {
		t.Fatalf("Decrypt() = %q, want %q", decrypted, plaintext)
	}
}

func TestEncryptUsesFreshNonce(t *testing.T) {
	first, err := Encrypt("same-input")
	if err != nil {
		t.Fatalf("Encrypt() error = %v", err)
	}
	second, err := Encrypt("same-input")
	if err != nil {
		t.Fatalf("Encrypt() error = %v", err)
	}
	if first == second {
		t.Fatal("Encrypt() must use a fresh nonce so ciphertexts differ")
	}
}

func TestEncryptDecryptEmpty(t *testing.T) {
	encrypted, err := Encrypt("")
	if err != nil {
		t.Fatalf("Encrypt(\"\") error = %v", err)
	}
	if encrypted != "" {
		t.Fatalf("Encrypt(\"\") = %q, want empty", encrypted)
	}

	decrypted, err := Decrypt("")
	if err != nil {
		t.Fatalf("Decrypt(\"\") error = %v", err)
	}
	if decrypted != "" {
		t.Fatalf("Decrypt(\"\") = %q, want empty", decrypted)
	}
}

func TestDecryptTamperedCiphertext(t *testing.T) {
	encrypted, err := Encrypt("hello world")
	if err != nil {
		t.Fatalf("Encrypt() error = %v", err)
	}
	data, err := base64.StdEncoding.DecodeString(encrypted)
	if err != nil {
		t.Fatalf("decode ciphertext: %v", err)
	}
	data[len(data)-1] ^= 0xFF
	tampered := base64.StdEncoding.EncodeToString(data)

	if _, err := Decrypt(tampered); err == nil {
		t.Fatal("Decrypt() must reject tampered ciphertext")
	}
}

func TestDecryptMalformedInput(t *testing.T) {
	if _, err := Decrypt("not-valid-base64!!!"); err == nil {
		t.Fatal("Decrypt() must reject malformed base64")
	}
	if _, err := Decrypt(base64.StdEncoding.EncodeToString([]byte("short"))); err == nil {
		t.Fatal("Decrypt() must reject ciphertext shorter than a nonce")
	}
}

func TestKeyFileCreated(t *testing.T) {
	// 触发密钥初始化（生成并落盘）。
	if _, err := Encrypt("trigger-key-init"); err != nil {
		t.Fatalf("Encrypt() error = %v", err)
	}

	path := KeyFilePath()
	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("key file not created at %s: %v", path, err)
	}
	if info.IsDir() {
		t.Fatalf("key path %s is a directory", path)
	}
	if info.Size() != 32 {
		t.Fatalf("key file size = %d, want 32", info.Size())
	}
}
