# PiControl Helper API Documentation

## Overview
This API provides management capabilities for Linux package installation and systemd services. It supports Debian-based (Ubuntu, Debian, Mint, Pop!_OS), Fedora, and Arch Linux distributions.

## Base URL
`http://localhost:8220`

## Endpoints

### Server Status
**GET /status**

Check the server status and identify the Linux distribution.

**Response:**
```json
{
  "status": "running",
  "distribution": "debian"
}
```

---

### Package Management

#### Install Packages
**POST /install**

Install one or more packages on the system.

**Request Body:**
```json
{
  "packages": ["package1", "package2"]
}
```

**Response:**
```json
{
  "distribution": "debian",
  "results": [
    {
      "package": "package1",
      "success": true,
      "message": "Installation output..."
    },
    {
      "package": "package2",
      "success": false,
      "message": "Error message..."
    }
  ]
}
```

#### Uninstall Packages
**POST /uninstall**

Remove one or more packages from the system.

**Request Body:**
```json
{
  "packages": ["package1", "package2"]
}
```

**Response:**
```json
{
  "distribution": "debian",
  "results": [
    {
      "package": "package1",
      "success": true,
      "message": "Uninstallation output..."
    },
    {
      "package": "package2",
      "success": false,
      "message": "Error message..."
    }
  ]
}
```

#### Search Packages
**GET /search?query=term**

Search for packages matching a query term.

**Query Parameters:**
- `query` - Search term to match packages

**Response:**
```json
{
  "distribution": "debian",
  "query": "term",
  "success": true,
  "results": [
    {
      "name": "package1",
      "description": "Package description"
    },
    {
      "name": "package2",
      "description": "Package description"
    }
  ]
}
```

#### List Installed Packages
**GET /list_installed**

List all packages installed on the system.

**Response:**
```json
{
  "distribution": "debian",
  "success": true,
  "packages": [
    {
      "name": "package1",
      "version": "1.0.0"
    },
    {
      "name": "package2",
      "version": "2.3.4"
    }
  ]
}
```

---

### Service Management

#### List Systemd Services
**GET /services**

List all systemd services on the system.

**Response:**
```json
{
  "success": true,
  "services": [
    {
      "name": "service1.service",
      "load_state": "loaded",
      "active_state": "active",
      "sub_state": "running",
      "description": "Service description"
    },
    {
      "name": "service2.service",
      "load_state": "loaded",
      "active_state": "inactive",
      "sub_state": "dead",
      "description": "Service description"
    }
  ]
}
```

#### Get Service Status
**GET /service/status?name=serviceName**

Get the status of a specific systemd service.

**Query Parameters:**
- `name` - Name of the service

**Response:**
```json
{
  "success": true,
  "service": "serviceName.service",
  "active_status": "active (running)",
  "enabled_status": "enabled",
  "full_status": "Detailed status output..."
}
```

#### Control Service
**POST /service/control**

Control a systemd service (start, stop, restart, enable, disable).

**Request Body:**
```json
{
  "service": "serviceName",
  "action": "start"
}
```

**Supported Actions:**
- `start`: Start the service
- `stop`: Stop the service
- `restart`: Restart the service
- `enable`: Enable the service to start at boot
- `disable`: Disable the service from starting at boot

**Response:**
```json
{
  "success": true,
  "service": "serviceName.service",
  "action": "start",
  "message": "Action output..."
}
```

## Error Responses

All endpoints return appropriate HTTP status codes:
- `200 OK` for successful operations
- `400 Bad Request` for invalid requests
- Error responses contain a JSON object with an "error" field describing the issue

Example error response:
```json
{
  "error": "No packages specified"
}
```
