package handlers

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base32"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/pquerna/otp/totp"
	"github.com/skip2/go-qrcode"
)

var (
	sessions     = make(map[string]*Session)
	totpSecret   string
	configDir    = "/opt/picontrol-helper/config"
	secretFile   = filepath.Join(configDir, "totp_secret.json")
	sessionValid = 25 * time.Minute
)

type Session struct {
	ID        string    `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	ExpiresAt time.Time `json:"expires_at"`
}

type TOTPConfig struct {
	Secret      string    `json:"secret"`
	QRCodePath  string    `json:"qr_code_path"`
	AccountName string    `json:"account_name"`
	Issuer      string    `json:"issuer"`
	CreatedAt   time.Time `json:"created_at"`
}

type AuthRequest struct {
	TOTPCode string `json:"totp_code"`
}

type AuthResponse struct {
	Success   bool   `json:"success"`
	SessionID string `json:"session_id,omitempty"`
	ExpiresAt string `json:"expires_at,omitempty"`
	Message   string `json:"message,omitempty"`
}

// InitializeAuth sets up the TOTP secret and generates QR code if needed
func InitializeAuth() error {
	// Create config directory if it doesn't exist
	if err := os.MkdirAll(configDir, 0750); err != nil {
		return fmt.Errorf("failed to create config directory: %v", err)
	}

	// Check if TOTP secret already exists
	if _, err := os.Stat(secretFile); os.IsNotExist(err) {
		return generateNewTOTPSecret()
	}

	// Load existing secret
	return loadTOTPSecret()
}

func generateNewTOTPSecret() error {
	log.Println("🔐 Setting up TOTP authentication for first time...")

	// Generate a new secret
	secret := make([]byte, 20)
	_, err := rand.Read(secret)
	if err != nil {
		return fmt.Errorf("failed to generate random secret: %v", err)
	}

	totpSecret = base32.StdEncoding.EncodeToString(secret)

	// Get hostname for account name
	hostname, _ := os.Hostname()
	if hostname == "" {
		hostname = "picontrol-server"
	}

	accountName := fmt.Sprintf("PiControl@%s", hostname)
	issuer := "PiControl Helper"

	// Generate TOTP key - the library expects the secret to be provided as raw bytes
	key, err := totp.Generate(totp.GenerateOpts{
		Issuer:      issuer,
		AccountName: accountName,
		Secret:      secret,
	})
	if err != nil {
		return fmt.Errorf("failed to generate TOTP key: %v", err)
	}

	// Generate QR code using the URL from the TOTP key
	qrCodePath := filepath.Join(configDir, "totp_qr.png")
	qrCode, err := qrcode.Encode(key.URL(), qrcode.Medium, 256)
	if err != nil {
		return fmt.Errorf("failed to generate QR code: %v", err)
	}

	err = ioutil.WriteFile(qrCodePath, qrCode, 0644)
	if err != nil {
		return fmt.Errorf("failed to save QR code: %v", err)
	}

	// Save config
	config := TOTPConfig{
		Secret:      totpSecret,
		QRCodePath:  qrCodePath,
		AccountName: accountName,
		Issuer:      issuer,
		CreatedAt:   time.Now(),
	}

	configData, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal config: %v", err)
	}

	err = ioutil.WriteFile(secretFile, configData, 0600)
	if err != nil {
		return fmt.Errorf("failed to save config: %v", err)
	}

	// Display QR code in terminal
	displayQRCodeInTerminal(key.URL())

	log.Println("✅ TOTP authentication setup complete!")
	log.Printf("📱 QR code saved to: %s", qrCodePath)
	log.Printf("🔑 Secret backup saved to: %s", secretFile)
	log.Println("📲 Scan the QR code with your authenticator app (Google Authenticator, Authy, etc.)")
	log.Printf("🏷️  Account: %s", accountName)
	log.Printf("🏢 Issuer: %s", issuer)
	log.Println("⚠️  Keep the secret file secure - it's needed for authentication!")

	return nil
}

func loadTOTPSecret() error {
	data, err := ioutil.ReadFile(secretFile)
	if err != nil {
		return fmt.Errorf("failed to read secret file: %v", err)
	}

	var config TOTPConfig
	err = json.Unmarshal(data, &config)
	if err != nil {
		return fmt.Errorf("failed to parse secret file: %v", err)
	}

	totpSecret = config.Secret
	log.Println("🔐 TOTP authentication loaded from existing configuration")
	return nil
}

func displayQRCodeInTerminal(url string) {
	// Generate ASCII QR code for terminal display
	qr, err := qrcode.New(url, qrcode.Medium)
	if err != nil {
		log.Printf("Failed to generate terminal QR code: %v", err)
		return
	}

	fmt.Println("\n" + strings.Repeat("=", 60))
	fmt.Println("📱 SCAN THIS QR CODE WITH YOUR AUTHENTICATOR APP 📱")
	fmt.Println(strings.Repeat("=", 60))

	// Convert QR code to ASCII art
	asciiArt := qr.ToSmallString(false)
	fmt.Println(asciiArt)

	fmt.Println(strings.Repeat("=", 60))
	fmt.Printf("🔗 Or manually enter this URL in your app:\n%s\n", url)
	fmt.Println(strings.Repeat("=", 60) + "\n")
}

// AuthenticateHandler handles TOTP authentication
func AuthenticateHandler(c *fiber.Ctx) error {
	var req AuthRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(400).JSON(AuthResponse{
			Success: false,
			Message: "Invalid JSON body",
		})
	}

	if req.TOTPCode == "" {
		return c.Status(400).JSON(AuthResponse{
			Success: false,
			Message: "TOTP code is required",
		})
	}

	// Validate TOTP code with time skew tolerance
	valid := totp.Validate(req.TOTPCode, totpSecret)
	if !valid {
		// Try with previous and next time windows for clock skew tolerance
		now := time.Now()
		prev := now.Add(-30 * time.Second)
		next := now.Add(30 * time.Second)

		prevCode, _ := totp.GenerateCode(totpSecret, prev)
		nextCode, _ := totp.GenerateCode(totpSecret, next)

		if req.TOTPCode == prevCode || req.TOTPCode == nextCode {
			valid = true
		}
	}

	if !valid {
		log.Printf("⚠️  Invalid TOTP attempt from %s", c.IP())
		return c.Status(401).JSON(AuthResponse{
			Success: false,
			Message: "Invalid TOTP code",
		})
	}

	// Generate session
	sessionID, expiresAt, err := createSession()
	if err != nil {
		return c.Status(500).JSON(AuthResponse{
			Success: false,
			Message: "Failed to create session",
		})
	}

	log.Printf("✅ Successful authentication from %s, session: %s", c.IP(), sessionID[:8]+"...")

	return c.JSON(AuthResponse{
		Success:   true,
		SessionID: sessionID,
		ExpiresAt: expiresAt.Format(time.RFC3339),
		Message:   "Authentication successful",
	})
}

func createSession() (string, time.Time, error) {
	// Generate session ID
	sessionBytes := make([]byte, 32)
	_, err := rand.Read(sessionBytes)
	if err != nil {
		return "", time.Time{}, err
	}

	hash := sha256.Sum256(sessionBytes)
	sessionID := hex.EncodeToString(hash[:])

	now := time.Now()
	expiresAt := now.Add(sessionValid)

	session := &Session{
		ID:        sessionID,
		CreatedAt: now,
		ExpiresAt: expiresAt,
	}

	sessions[sessionID] = session

	// Clean up expired sessions
	go cleanupExpiredSessions()

	return sessionID, expiresAt, nil
}

func cleanupExpiredSessions() {
	now := time.Now()
	for id, session := range sessions {
		if now.After(session.ExpiresAt) {
			delete(sessions, id)
		}
	}
}

// ValidateSession checks if a session is valid
func ValidateSession(sessionID string) bool {
	session, exists := sessions[sessionID]
	if !exists {
		return false
	}

	if time.Now().After(session.ExpiresAt) {
		delete(sessions, sessionID)
		return false
	}

	return true
}

// AuthMiddleware protects endpoints with session validation
func AuthMiddleware(c *fiber.Ctx) error {
	// Check for session ID in Authorization header
	authHeader := c.Get("Authorization")
	if authHeader == "" {
		return c.Status(401).JSON(fiber.Map{
			"error": "Authorization header required",
		})
	}

	// Extract session ID (expect format: "Bearer <session_id>")
	sessionID := ""
	if len(authHeader) > 7 && authHeader[:7] == "Bearer " {
		sessionID = authHeader[7:]
	} else {
		sessionID = authHeader
	}

	if !ValidateSession(sessionID) {
		return c.Status(401).JSON(fiber.Map{
			"error": "Invalid or expired session",
		})
	}

	return c.Next()
}

// GetAuthStatus returns current authentication status
func GetAuthStatus(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"totp_enabled":    totpSecret != "",
		"config_path":     configDir,
		"active_sessions": len(sessions),
		"secret_loaded":   totpSecret != "",
	})
}

// RegenerateTOTP regenerates TOTP secret (requires existing authentication)
func RegenerateTOTP(c *fiber.Ctx) error {
	// Remove old config
	os.Remove(secretFile)
	os.Remove(filepath.Join(configDir, "totp_qr.png"))

	// Generate new secret
	err := generateNewTOTPSecret()
	if err != nil {
		return c.Status(500).JSON(fiber.Map{
			"error":   "Failed to regenerate TOTP",
			"message": err.Error(),
		})
	}

	// Clear all existing sessions
	sessions = make(map[string]*Session)

	return c.JSON(fiber.Map{
		"success": true,
		"message": "TOTP secret regenerated successfully. All sessions have been invalidated.",
	})
}

// GetSessionStatus returns information about the current session
func GetSessionStatus(c *fiber.Ctx) error {
	authHeader := c.Get("Authorization")
	if authHeader == "" {
		return c.Status(401).JSON(fiber.Map{
			"error": "Authorization header required",
		})
	}

	sessionID := ""
	if len(authHeader) > 7 && authHeader[:7] == "Bearer " {
		sessionID = authHeader[7:]
	} else {
		sessionID = authHeader
	}

	session, exists := sessions[sessionID]
	if !exists {
		return c.Status(401).JSON(fiber.Map{
			"error": "Session not found",
		})
	}

	if time.Now().After(session.ExpiresAt) {
		delete(sessions, sessionID)
		return c.Status(401).JSON(fiber.Map{
			"error": "Session expired",
		})
	}

	timeRemaining := time.Until(session.ExpiresAt)

	return c.JSON(fiber.Map{
		"valid":          true,
		"session_id":     sessionID[:16] + "...", // Only show first 16 chars for security
		"created_at":     session.CreatedAt.Format(time.RFC3339),
		"expires_at":     session.ExpiresAt.Format(time.RFC3339),
		"time_remaining": timeRemaining.String(),
		"expires_in_sec": int(timeRemaining.Seconds()),
	})
}

// LogoutHandler invalidates a session
func LogoutHandler(c *fiber.Ctx) error {
	authHeader := c.Get("Authorization")
	if authHeader == "" {
		return c.Status(400).JSON(fiber.Map{
			"error": "No session to logout",
		})
	}

	sessionID := ""
	if len(authHeader) > 7 && authHeader[:7] == "Bearer " {
		sessionID = authHeader[7:]
	} else {
		sessionID = authHeader
	}

	delete(sessions, sessionID)

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Logged out successfully",
	})
}
