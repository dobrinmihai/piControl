# Pi Control IoT - Go Fiber Implementation

A Go rewrite of the Python Flask SSH terminal application using Fiber framework with SSL WebSocket support.

## Features

- Network scanning to discover devices with IP and MAC addresses
- SSH terminal access through WebSockets with SSL encryption
- Cross-platform network discovery (Linux focused)
- Real-time terminal interaction

## Prerequisites

- Go 1.21 or higher
- Linux system with `nmap` or `arp-scan` installed
- SSL certificates (for HTTPS/WSS)

## Installation

1. Install dependencies:
```bash
go mod tidy
```

2. Generate SSL certificates:
```bash
chmod +x generate-certs.sh
./generate-certs.sh
```

3. Install network scanning tools (Linux):
```bash
# Ubuntu/Debian
sudo apt-get install nmap arp-scan

# CentOS/RHEL
sudo yum install nmap arp-scan
```

## Usage

1. Start the server:
```bash
go run main.go
```

2. The server will start on port 3000 with SSL enabled

## API Endpoints

### REST API
- `GET /scan` - Scan network for devices (returns JSON array of devices with IP and MAC)

### WebSocket API
- `ws://localhost:3000/ws` (or `wss://` with SSL)

WebSocket message types:
- `start_ssh` - Initiate SSH connection
- `input` - Send input to SSH session

## WebSocket Message Format

```json
{
  "type": "start_ssh",
  "hostname": "192.168.1.100",
  "username": "pi",
  "password": "raspberry"
}
```

```json
{
  "type": "input", 
  "data": "ls -la\n"
}
```

## Security

- Uses SSL/TLS for encrypted WebSocket connections
- SSH connections use standard SSH authentication
- Self-signed certificates included for development (replace with proper certs for production)

## Network Scanning

The application scans the `192.168.1.0/24` network range by default. It uses:
1. `nmap -sn` for network discovery
2. Falls back to `arp-scan --local` if nmap fails

## Building

```bash
go build -o picontrol-iot main.go
```

## License

Same as original project