# PiControl Helper API Documentation

Complete API reference for PiControl Helper - a secure package and service management tool with TOTP authentication.

**Version:** 1.0  
**Base URL:** `http://localhost:8220`  
**Authentication:** TOTP-based with session tokens  

---

## Table of Contents

1. [Authentication Overview](#authentication-overview)
2. [Public Endpoints](#public-endpoints)
3. [Authentication Endpoints](#authentication-endpoints)
4. [Protected Endpoints](#protected-endpoints)
5. [Package Management](#package-management)
6. [Service Management](#service-management)
7. [Session Management](#session-management)
8. [Error Responses](#error-responses)
9. [Examples](#examples)
10. [SDKs and Clients](#sdks-and-clients)

---

## Authentication Overview

PiControl Helper uses **Time-based One-Time Password (TOTP)** authentication with session management:

1. **Setup:** On first startup, scan QR code with authenticator app
2. **Authenticate:** POST TOTP code to `/auth` to get session token
3. **Use APIs:** Include session token in `Authorization` header for protected endpoints
4. **Sessions:** Tokens expire after 25 minutes of inactivity

### Session Token Format
```
Authorization: Bearer <session_token>
```
Or simply:
```
Authorization: <session_token>
```

---

## Public Endpoints

These endpoints do not require authentication.

### Get Server Status

Get basic server information and health status.

**Endpoint:** `GET /status`

**Response:**
```json
{
  "status": "running",
  "distribution": "debian"
}
```

**Response Fields:**
- `status` (string): Server status ("running")
- `distribution` (string): Detected Linux distribution

**Example:**
```bash
curl http://localhost:8220/status
```

---

## Authentication Endpoints

### Authenticate with TOTP

Authenticate using TOTP code from authenticator app to obtain session token.

**Endpoint:** `POST /auth`

**Request Body:**
```json
{
  "totp_code": "123456"
}
```

**Request Fields:**
- `totp_code` (string, required): 6-digit TOTP code from authenticator app

**Success Response (200):**
```json
{
  "success": true,
  "session_id": "abc123def456...",
  "expires_at": "2025-06-18T19:25:00Z",
  "message": "Authentication successful"
}
```

**Error Response (401):**
```json
{
  "success": false,
  "message": "Invalid TOTP code"
}
```

**Example:**
```bash
curl -X POST http://localhost:8220/auth \
  -H "Content-Type: application/json" \
  -d '{"totp_code":"123456"}'
```

### Get Authentication Status

Get current authentication system status.

**Endpoint:** `GET /auth/status`

**Response:**
```json
{
  "totp_enabled": true,
  "config_path": "/opt/picontrol-helper/config",
  "active_sessions": 2,
  "secret_loaded": true
}
```

**Response Fields:**
- `totp_enabled` (boolean): Whether TOTP is enabled
- `config_path` (string): Configuration directory path
- `active_sessions` (integer): Number of active sessions
- `secret_loaded` (boolean): Whether TOTP secret is loaded

**Example:**
```bash
curl http://localhost:8220/auth/status
```

---

## Protected Endpoints

All endpoints under `/api/*` require authentication via session token.

---

## Package Management

### Search Packages

Search for packages in the distribution's package repository.

**Endpoint:** `GET /api/search`

**Query Parameters:**
- `query` (string, required): Package name or keyword to search

**Response:**
```json
{
  "distribution": "debian",
  "query": "htop",
  "success": true,
  "results": [
    {
      "name": "htop",
      "description": "interactive processes viewer"
    },
    {
      "name": "htop-dev",
      "description": "development files for htop"
    }
  ]
}
```

**Response Fields:**
- `distribution` (string): Linux distribution
- `query` (string): Search query used
- `success` (boolean): Operation success status
- `results` (array): Array of package objects

**Package Object:**
- `name` (string): Package name
- `description` (string): Package description

**Example:**
```bash
curl -X GET "http://localhost:8220/api/search?query=htop" \
  -H "Authorization: Bearer <session_token>"
```

### Install Packages

Install one or more packages using the system package manager.

**Endpoint:** `POST /api/install`

**Request Body:**
```json
{
  "packages": ["htop", "curl", "git"]
}
```

**Request Fields:**
- `packages` (array, required): Array of package names to install

**Response:**
```json
{
  "distribution": "debian",
  "results": [
    {
      "package": "htop",
      "success": true,
      "message": "Package installed successfully"
    },
    {
      "package": "nonexistent",
      "success": false,
      "message": "Package not found"
    }
  ]
}
```

**Response Fields:**
- `distribution` (string): Linux distribution
- `results` (array): Array of installation result objects

**Result Object:**
- `package` (string): Package name
- `success` (boolean): Installation success status
- `message` (string): Status message or error details

**Example:**
```bash
curl -X POST http://localhost:8220/api/install \
  -H "Authorization: Bearer <session_token>" \
  -H "Content-Type: application/json" \
  -d '{"packages":["htop","curl"]}'
```

### Uninstall Packages

Remove one or more packages from the system.

**Endpoint:** `POST /api/uninstall`

**Request Body:**
```json
{
  "packages": ["htop", "curl"]
}
```

**Request Fields:**
- `packages` (array, required): Array of package names to uninstall

**Response:**
```json
{
  "distribution": "debian",
  "results": [
    {
      "package": "htop",
      "success": true,
      "message": "Package removed successfully"
    }
  ]
}
```

**Example:**
```bash
curl -X POST http://localhost:8220/api/uninstall \
  -H "Authorization: Bearer <session_token>" \
  -H "Content-Type: application/json" \
  -d '{"packages":["htop"]}'
```

### List Installed Packages

Get a list of all installed packages on the system.

**Endpoint:** `GET /api/list_installed`

**Response:**
```json
{
  "distribution": "debian",
  "success": true,
  "packages": [
    {
      "name": "htop",
      "version": "3.0.5-7"
    },
    {
      "name": "curl",
      "version": "7.88.1-10"
    }
  ]
}
```

**Response Fields:**
- `distribution` (string): Linux distribution
- `success` (boolean): Operation success status
- `packages` (array): Array of installed package objects

**Package Object:**
- `name` (string): Package name
- `version` (string): Installed version

**Example:**
```bash
curl -X GET http://localhost:8220/api/list_installed \
  -H "Authorization: Bearer <session_token>"
```

---

## Service Management

### List Services

Get a list of all systemd services on the system.

**Endpoint:** `GET /api/services`

**Response:**
```json
{
  "success": true,
  "services": [
    {
      "name": "ssh.service",
      "load_state": "loaded",
      "active_state": "active",
      "sub_state": "running",
      "description": "OpenBSD Secure Shell server"
    },
    {
      "name": "nginx.service",
      "load_state": "loaded",
      "active_state": "inactive",
      "sub_state": "dead",
      "description": "A high performance web server"
    }
  ]
}
```

**Response Fields:**
- `success` (boolean): Operation success status
- `services` (array): Array of service objects

**Service Object:**
- `name` (string): Service name
- `load_state` (string): Service load state (loaded, not-found, etc.)
- `active_state` (string): Service active state (active, inactive, failed, etc.)
- `sub_state` (string): Service sub-state (running, dead, etc.)
- `description` (string): Service description

**Example:**
```bash
curl -X GET http://localhost:8220/api/services \
  -H "Authorization: Bearer <session_token>"
```

### Get Service Status

Get detailed status information for a specific service.

**Endpoint:** `GET /api/service/status`

**Query Parameters:**
- `name` (string, required): Service name (with or without .service suffix)

**Response:**
```json
{
  "success": true,
  "service": "ssh.service",
  "active_status": "active (running) since Mon 2025-06-18 19:00:00 UTC; 2h ago",
  "enabled_status": "enabled",
  "full_status": "● ssh.service - OpenBSD Secure Shell server\n   Loaded: loaded (/lib/systemd/system/ssh.service; enabled; vendor preset: enabled)\n   Active: active (running) since Mon 2025-06-18 19:00:00 UTC; 2h ago\n..."
}
```

**Response Fields:**
- `success` (boolean): Operation success status
- `service` (string): Service name
- `active_status` (string): Parsed active status
- `enabled_status` (string): Service enabled status
- `full_status` (string): Complete systemctl status output

**Example:**
```bash
curl -X GET "http://localhost:8220/api/service/status?name=ssh" \
  -H "Authorization: Bearer <session_token>"
```

### Control Service

Start, stop, restart, enable, or disable a service.

**Endpoint:** `POST /api/service/control`

**Request Body:**
```json
{
  "service": "nginx",
  "action": "start"
}
```

**Request Fields:**
- `service` (string, required): Service name (with or without .service suffix)
- `action` (string, required): Action to perform (start, stop, restart, enable, disable)

**Valid Actions:**
- `start` - Start the service
- `stop` - Stop the service
- `restart` - Restart the service
- `enable` - Enable service to start at boot
- `disable` - Disable service from starting at boot

**Success Response:**
```json
{
  "success": true,
  "service": "nginx.service",
  "action": "start",
  "message": "Service started successfully"
}
```

**Error Response:**
```json
{
  "success": false,
  "service": "nginx.service",
  "action": "start",
  "message": "Failed to start nginx.service: Job for nginx.service failed"
}
```

**Example:**
```bash
curl -X POST http://localhost:8220/api/service/control \
  -H "Authorization: Bearer <session_token>" \
  -H "Content-Type: application/json" \
  -d '{"service":"nginx","action":"start"}'
```

---

## Session Management

### Get Session Status

Get information about the current session including expiration time.

**Endpoint:** `GET /api/auth/session`

**Response:**
```json
{
  "valid": true,
  "session_id": "ef7952f0250a4466...",
  "created_at": "2025-06-18T19:00:00Z",
  "expires_at": "2025-06-18T19:25:00Z",
  "time_remaining": "23m45s",
  "expires_in_sec": 1425
}
```

**Response Fields:**
- `valid` (boolean): Session validity status
- `session_id` (string): Truncated session ID (first 16 chars + "...")
- `created_at` (string): Session creation timestamp (RFC3339)
- `expires_at` (string): Session expiration timestamp (RFC3339)
- `time_remaining` (string): Human-readable time until expiration
- `expires_in_sec` (integer): Seconds until expiration

**Example:**
```bash
curl -X GET http://localhost:8220/api/auth/session \
  -H "Authorization: Bearer <session_token>"
```

### Regenerate TOTP Secret

Generate a new TOTP secret and invalidate all existing sessions. Use this if you lose access to your authenticator app.

**Endpoint:** `POST /api/auth/regenerate`

**Response:**
```json
{
  "success": true,
  "message": "TOTP secret regenerated successfully. All sessions have been invalidated."
}
```

**Note:** After regeneration, check server logs for the new QR code to scan with your authenticator app.

**Example:**
```bash
curl -X POST http://localhost:8220/api/auth/regenerate \
  -H "Authorization: Bearer <session_token>"
```

### Logout

Invalidate the current session.

**Endpoint:** `POST /api/auth/logout`

**Response:**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

**Example:**
```bash
curl -X POST http://localhost:8220/api/auth/logout \
  -H "Authorization: Bearer <session_token>"
```

---

## Error Responses

### HTTP Status Codes

- **200** - Success
- **400** - Bad Request (invalid request body, missing parameters)
- **401** - Unauthorized (invalid/missing session token, invalid TOTP)
- **500** - Internal Server Error

### Common Error Response Format

```json
{
  "error": "Error description",
  "message": "Detailed error message"
}
```

### Authentication Errors

```json
{
  "success": false,
  "message": "Invalid TOTP code"
}
```

### Session Errors

```json
{
  "error": "Invalid or expired session"
}
```

---

## Examples

### Complete Authentication Flow

```bash
# 1. Check server status
curl http://localhost:8220/status

# 2. Get TOTP code from authenticator app (e.g., 123456)

# 3. Authenticate
RESPONSE=$(curl -s -X POST http://localhost:8220/auth \
  -H "Content-Type: application/json" \
  -d '{"totp_code":"123456"}')

# 4. Extract session token
SESSION_TOKEN=$(echo $RESPONSE | jq -r '.session_id')

# 5. Use API with session token
curl -X GET http://localhost:8220/api/services \
  -H "Authorization: Bearer $SESSION_TOKEN"
```

### Package Management Workflow

```bash
# Search for packages
curl -X GET "http://localhost:8220/api/search?query=nginx" \
  -H "Authorization: Bearer $SESSION_TOKEN"

# Install packages
curl -X POST http://localhost:8220/api/install \
  -H "Authorization: Bearer $SESSION_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"packages":["nginx","htop"]}'

# List installed packages
curl -X GET http://localhost:8220/api/list_installed \
  -H "Authorization: Bearer $SESSION_TOKEN"
```

### Service Management Workflow

```bash
# List all services
curl -X GET http://localhost:8220/api/services \
  -H "Authorization: Bearer $SESSION_TOKEN"

# Check specific service status
curl -X GET "http://localhost:8220/api/service/status?name=nginx" \
  -H "Authorization: Bearer $SESSION_TOKEN"

# Start a service
curl -X POST http://localhost:8220/api/service/control \
  -H "Authorization: Bearer $SESSION_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"service":"nginx","action":"start"}'

# Enable service at boot
curl -X POST http://localhost:8220/api/service/control \
  -H "Authorization: Bearer $SESSION_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"service":"nginx","action":"enable"}'
```

---

## SDKs and Clients

### Official Client

A bash-based client is provided: `example_client.sh`

**Usage:**
```bash
# Interactive mode
./example_client.sh interactive

# Direct commands
./example_client.sh auth 123456
./example_client.sh search nginx
./example_client.sh install "nginx htop"
./example_client.sh services
./example_client.sh session
```

### Python SDK Example

```python
import requests
import json

class PiControlClient:
    def __init__(self, base_url="http://localhost:8220"):
        self.base_url = base_url
        self.session_token = None
    
    def authenticate(self, totp_code):
        response = requests.post(
            f"{self.base_url}/auth",
            json={"totp_code": totp_code}
        )
        if response.status_code == 200:
            data = response.json()
            self.session_token = data["session_id"]
            return True
        return False
    
    def _headers(self):
        return {"Authorization": f"Bearer {self.session_token}"}
    
    def search_packages(self, query):
        response = requests.get(
            f"{self.base_url}/api/search",
            headers=self._headers(),
            params={"query": query}
        )
        return response.json()
    
    def install_packages(self, packages):
        response = requests.post(
            f"{self.base_url}/api/install",
            headers=self._headers(),
            json={"packages": packages}
        )
        return response.json()

# Usage
client = PiControlClient()
client.authenticate("123456")
result = client.search_packages("nginx")
```

### JavaScript/Node.js SDK Example

```javascript
class PiControlClient {
    constructor(baseUrl = 'http://localhost:8220') {
        this.baseUrl = baseUrl;
        this.sessionToken = null;
    }

    async authenticate(totpCode) {
        const response = await fetch(`${this.baseUrl}/auth`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ totp_code: totpCode })
        });
        
        if (response.ok) {
            const data = await response.json();
            this.sessionToken = data.session_id;
            return true;
        }
        return false;
    }

    _headers() {
        return {
            'Authorization': `Bearer ${this.sessionToken}`,
            'Content-Type': 'application/json'
        };
    }

    async searchPackages(query) {
        const response = await fetch(
            `${this.baseUrl}/api/search?query=${encodeURIComponent(query)}`,
            { headers: this._headers() }
        );
        return response.json();
    }

    async installPackages(packages) {
        const response = await fetch(`${this.baseUrl}/api/install`, {
            method: 'POST',
            headers: this._headers(),
            body: JSON.stringify({ packages })
        });
        return response.json();
    }
}

// Usage
const client = new PiControlClient();
await client.authenticate('123456');
const result = await client.searchPackages('nginx');
```

---

## Rate Limiting and Security

### Security Features

- **TOTP Authentication**: Industry-standard time-based one-time passwords
- **Session Management**: 25-minute session expiration with automatic cleanup
- **Secure Headers**: Session tokens use SHA-256 hashing
- **Sudo Integration**: Proper privilege escalation for package and service management
- **Input Validation**: All inputs are validated and sanitized
- **Failed Attempt Logging**: Invalid authentication attempts are logged

### Best Practices

1. **Keep authenticator app secure** - Use device lock/biometrics
2. **Monitor session expiration** - Use `/api/auth/session` to check time remaining
3. **Use HTTPS in production** - Encrypt all API communications
4. **Backup TOTP secret** - Save QR code or secret in secure location
5. **Regular secret rotation** - Use `/api/auth/regenerate` periodically
6. **Monitor logs** - Check for suspicious authentication attempts

### Rate Limiting

Currently no rate limiting is implemented. In production environments, consider implementing:

- **Authentication rate limiting** - Prevent brute force TOTP attacks
- **API rate limiting** - Prevent API abuse
- **IP-based restrictions** - Limit access to known networks

---

## Troubleshooting

### Common Issues

**Invalid TOTP Code:**
- Ensure device time is synchronized
- Verify correct account in authenticator app
- TOTP codes expire every 30 seconds

**Session Expired:**
- Sessions expire after 25 minutes
- Re-authenticate to get new session token

**Permission Denied:**
- Ensure user is in `pkgmanagers` group
- Check sudoers configuration

**Service Not Found:**
- Verify service name (with or without .service suffix)
- Check if service exists: `systemctl list-units --type=service`

### Support Commands

```bash
# Check authentication status
curl http://localhost:8220/auth/status

# Check session status
curl -X GET http://localhost:8220/api/auth/session \
  -H "Authorization: Bearer <token>"

# Check server status
curl http://localhost:8220/status

# View server logs
sudo journalctl -u picontrol-helper.service -f
```

---

*This documentation is for PiControl Helper API version 1.0. For updates and support, check the project repository.*