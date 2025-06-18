# PiControl Helper Authentication System

This document describes the TOTP-based authentication system implemented in PiControl Helper.

## Overview

The PiControl Helper uses Time-based One-Time Password (TOTP) authentication for security. On first startup, the system generates a unique TOTP secret, displays a QR code in the terminal, and saves the configuration for future use.

## First-Time Setup

When you start PiControl Helper for the first time, it will:

1. **Generate a TOTP Secret**: A unique 20-byte secret is generated
2. **Display QR Code**: A QR code is shown in the terminal for easy setup
3. **Save Configuration**: The secret and QR code are saved to `/opt/picontrol-helper/config/`
4. **Create Backup**: Configuration is saved in JSON format for recovery

### Files Created

- `/opt/picontrol-helper/config/totp_secret.json` - Contains the TOTP configuration
- `/opt/picontrol-helper/config/totp_qr.png` - QR code image file

## Setting Up Your Authenticator App

1. **Install an Authenticator App** on your mobile device:
   - Google Authenticator
   - Authy
   - Microsoft Authenticator
   - Any TOTP-compatible app

2. **Scan the QR Code** displayed in the terminal when the service starts

3. **Manual Setup** (if QR code doesn't work):
   - Open your authenticator app
   - Add account manually
   - Enter the account name: `PiControl@<hostname>`
   - Enter the secret key from the terminal output

## API Endpoints

### Public Endpoints (No Authentication Required)

#### Get Server Status
```http
GET /status
```
Returns server status and distribution information.

#### Get Authentication Status
```http
GET /auth/status
```
Returns:
```json
{
  "totp_enabled": true,
  "config_path": "/opt/picontrol-helper/config",
  "active_sessions": 2
}
```

### Authentication

#### Authenticate with TOTP
```http
POST /auth
Content-Type: application/json

{
  "totp_code": "123456"
}
```

**Success Response:**
```json
{
  "success": true,
  "session_id": "abc123...",
  "expires_at": "2024-01-01T12:25:00Z",
  "message": "Authentication successful"
}
```

**Error Response:**
```json
{
  "success": false,
  "message": "Invalid TOTP code"
}
```

### Protected Endpoints (Require Authentication)

All API endpoints under `/api/` require authentication. Include the session ID in the Authorization header:

```http
Authorization: Bearer <session_id>
```

Or simply:
```http
Authorization: <session_id>
```

#### Session Status
```http
GET /api/auth/session
Authorization: Bearer <session_id>
```

**Response:**
```json
{
  "valid": true,
  "session_id": "5e4296e92fccb765...",
  "created_at": "2025-06-18T19:00:00Z",
  "expires_at": "2025-06-18T19:25:00Z",
  "time_remaining": "23m45s",
  "expires_in_sec": 1425
}
```

#### Package Management
- `POST /api/install` - Install packages
- `POST /api/uninstall` - Uninstall packages
- `GET /api/search` - Search packages
- `GET /api/list_installed` - List installed packages

#### Service Management
- `GET /api/services` - List all services
- `GET /api/service/status` - Get service status
- `POST /api/service/control` - Control service (start/stop/restart/enable/disable)

#### Authentication Management
- `GET /api/auth/session` - Get current session status and expiration info
- `POST /api/auth/regenerate` - Regenerate TOTP secret (invalidates all sessions)
- `POST /api/auth/logout` - Logout and invalidate current session

## Session Management

- **Session Duration**: 25 minutes
- **Automatic Cleanup**: Expired sessions are automatically removed
- **Session Validation**: Each request validates the session and extends it
- **Logout**: Sessions can be manually invalidated

## Security Features

1. **TOTP Validation**: Uses industry-standard TOTP algorithm
2. **Secure Session IDs**: 256-bit random session identifiers
3. **Session Expiration**: Automatic session timeout
4. **Failed Attempt Logging**: Invalid attempts are logged with IP addresses
5. **Configuration Protection**: Secret files have restricted permissions (600)

## Example Usage

### 1. Get TOTP Code from Your App
Open your authenticator app and get the 6-digit code for PiControl.

### 2. Authenticate
```bash
curl -X POST http://localhost:8220/auth \
  -H "Content-Type: application/json" \
  -d '{"totp_code":"123456"}'
```

### 3. Use Session ID for API Calls
```bash
# Save session ID from auth response
# Check status with saved session
SESSION_ID="your_session_id_here"

# Check session status
curl -X GET http://localhost:8220/api/auth/session \
  -H "Authorization: Bearer $SESSION_ID"

# Install a package
curl -X POST http://localhost:8220/api/install \
  -H "Authorization: Bearer $SESSION_ID" \
  -H "Content-Type: application/json" \
  -d '{"packages":["htop"]}'

# List services
curl -X GET http://localhost:8220/api/services \
  -H "Authorization: Bearer $SESSION_ID"
```

## Troubleshooting

### QR Code Not Displaying
If the QR code doesn't display properly in your terminal:
1. Check the saved QR code image: `/opt/picontrol-helper/config/totp_qr.png`
2. Use the manual setup URL shown in the terminal output

### Lost Authenticator Access
If you lose access to your authenticator app:
1. Stop the service: `sudo systemctl stop picontrol-helper`
2. Delete the config: `sudo rm -rf /opt/picontrol-helper/config/`
3. Start the service: `sudo systemctl start picontrol-helper`
4. A new TOTP secret will be generated

### Invalid TOTP Code
- Ensure your device's time is synchronized
- TOTP codes are time-sensitive (30-second windows)
- Check that you're using the correct account in your authenticator app

### Session Expired
Sessions automatically expire after 25 minutes of inactivity. Simply authenticate again to get a new session.

## Configuration File Format

The TOTP configuration is stored in JSON format:

```json
{
  "secret": "BASE32_ENCODED_SECRET",
  "qr_code_path": "/opt/picontrol-helper/config/totp_qr.png",
  "account_name": "PiControl@hostname",
  "issuer": "PiControl Helper",
  "created_at": "2024-01-01T12:00:00Z"
}
```

## Security Recommendations

1. **Backup Your Secret**: Save the QR code or secret in a secure location
2. **Use Multiple Devices**: Add the same account to multiple authenticator apps
3. **Regular Updates**: Keep your authenticator app updated
4. **Network Security**: Use HTTPS in production environments
5. **Monitor Logs**: Check logs for suspicious authentication attempts

## Development Notes

The authentication system uses:
- `github.com/pquerna/otp` for TOTP generation and validation
- `github.com/skip2/go-qrcode` for QR code generation
- SHA-256 for session ID generation
- Base32 encoding for TOTP secrets

Session storage is currently in-memory and will be reset when the service restarts. For production use, consider implementing persistent session storage.