#!/bin/bash

# PiControl Build Script
# Builds the SvelteKit frontend, NetSSH proxy, and Helper for deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_ROOT/dist"
FRONTEND_BUILD_DIR="$BUILD_DIR/frontend"
NETSSH_BUILD_DIR="$BUILD_DIR/netssh"

# Default values
TARGET_ARCH="amd64"
VERBOSE=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -a, --arch ARCH       Target architecture: amd64, arm64, or arm (default: amd64)"
    echo "  -v, --verbose         Enable verbose output"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  NETSSH_WS_URL        WebSocket URL for NetSSH proxy (default: wss://localhost:3000/ws)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Build for amd64"
    echo "  $0 -a arm64          # Build for arm64 (Raspberry Pi 4)"
    echo "  $0 -a arm            # Build for arm (Raspberry Pi 3)"
    echo "  NETSSH_WS_URL=wss://192.168.1.3:3000/ws $0 -a arm64  # Build with custom WebSocket URL"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--arch)
            TARGET_ARCH="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate architecture
case $TARGET_ARCH in
    amd64|arm64|arm)
        ;;
    *)
        print_error "Invalid architecture: $TARGET_ARCH"
        print_error "Supported architectures: amd64, arm64, arm"
        exit 1
        ;;
esac

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        exit 1
    fi
    
    # Check npm/bun
    if ! command -v bun &> /dev/null && ! command -v npm &> /dev/null; then
        print_error "Neither bun nor npm is installed"
        exit 1
    fi
    
    # Check Go
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to create production environment configuration
create_production_env() {
    print_status "Creating production environment configuration..."
    
    # Determine WebSocket URL based on deployment context
    # Default to relative URL for production, but allow override
    local netssh_ws_url="${NETSSH_WS_URL:-wss://localhost:3000/ws}"
    
    # Create .env.production file
    cat > ".env.production" << EOF
# PiControl Production Environment Configuration
NODE_ENV=production

# PocketBase Configuration
POCKETBASE_URL=http://localhost:8090

# NetSSH WebSocket Configuration
PUBLIC_NETSSH_WS_URL=${netssh_ws_url}
EOF
    
    print_success "Production environment configured"
}

# Function to clean build directories
clean_build() {
    print_status "Cleaning build directories..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$FRONTEND_BUILD_DIR" "$NETSSH_BUILD_DIR"
    print_success "Build directories cleaned"
}

# Function to build frontend
build_frontend() {
    print_status "Building SvelteKit frontend..."
    
    cd "$PROJECT_ROOT"
    
    # Create production environment file
    create_production_env
    
    # Install dependencies
    if command -v bun &> /dev/null; then
        print_status "Installing dependencies with bun..."
        bun install
        print_status "Building with bun..."
        bun run build
    else
        print_status "Installing dependencies with npm..."
        npm install
        print_status "Building with npm..."
        npm run build
    fi
    
    # Copy build output
    if [[ -d "build" ]]; then
        # For Node.js adapter, copy the entire build directory
        cp -r build/* "$FRONTEND_BUILD_DIR/"
        
        # Create package.json for ES module support with all runtime dependencies
        cat > "$FRONTEND_BUILD_DIR/package.json" << EOF
{
  "type": "module",
  "dependencies": {
    "@auth0/auth0-spa-js": "^2.1.3",
    "@iconify/svelte": "^5.0.0",
    "@picocss/pico": "^2.1.1",
    "@polka/url": "^1.0.0-next.23",
    "@sveltejs/kit": "^2.16.0",
    "@tailwindcss/vite": "^4.1.5",
    "@types/xterm": "^3.0.0",
    "@xterm/xterm": "^5.5.0",
    "pocketbase": "^0.26.0",
    "socket.io-client": "^4.8.1",
    "tailwindcss": "^4.1.5",
    "xterm-addon-fit": "^0.8.0",
    "xterm-addon-web-links": "^0.9.0"
  }
}
EOF
        
        print_success "Frontend built successfully"
    else
        print_error "Frontend build failed - no build directory found"
        exit 1
    fi
}

# Function to build NetSSH proxy
build_netssh() {
    print_status "Building NetSSH proxy for linux/$TARGET_ARCH..."
    
    cd "$PROJECT_ROOT/src-netssh"
    
    # Build for target architecture
    GOOS=linux GOARCH=$TARGET_ARCH go build -o "$NETSSH_BUILD_DIR/netssh-proxy" .
    
    print_success "NetSSH proxy built successfully"
}

# Function to create deployment package
create_deployment_package() {
    print_status "Creating deployment package..."
    
    # Create version info
    cat > "$BUILD_DIR/build-info.txt" << EOF
Build Date: $(date)
Architecture: linux/$TARGET_ARCH
Frontend: SvelteKit
NetSSH Proxy: Go
EOF
    
    # Create deployment structure info
    cat > "$BUILD_DIR/README.md" << EOF
# PiControl Deployment Package

Built on: $(date)
Architecture: linux/$TARGET_ARCH

## Contents

- \`frontend/\` - SvelteKit frontend static files
- \`netssh/netssh-proxy\` - NetSSH proxy binary
- \`build-info.txt\` - Build information

## Deployment

Use the \`deploy.sh\` script on the target machine to deploy these files.
Note: PiControl Helper should be built and deployed separately using its own build script.

## Service Ports

- Frontend: 3000 (served by web server)
- NetSSH Proxy: 3000
- PiControl Helper: 8220 (separate deployment)
- PocketBase: 8090 (separate installation)

## Architecture

This package was built for: linux/$TARGET_ARCH
EOF
    
    # Create a deployment manifest
    cat > "$BUILD_DIR/manifest.json" << EOF
{
    "build_date": "$(date -Iseconds)",
    "architecture": "linux/$TARGET_ARCH",
    "components": {
        "frontend": {
            "type": "static",
            "path": "frontend/",
            "port": 3000
        },
        "netssh": {
            "type": "binary",
            "path": "netssh/netssh-proxy",
            "port": 3000
        }
    }
}
EOF
    
    # Make binaries executable
    chmod +x "$NETSSH_BUILD_DIR/netssh-proxy"
    
    print_success "Deployment package created"
}

# Function to create deployment archive
create_archive() {
    print_status "Creating deployment archive..."
    
    cd "$PROJECT_ROOT"
    
    # Create tar.gz archive
    ARCHIVE_NAME="picontrol-$(date +%Y%m%d-%H%M%S)-linux-$TARGET_ARCH.tar.gz"
    tar -czf "$ARCHIVE_NAME" -C "$BUILD_DIR" .
    
    print_success "Deployment archive created: $ARCHIVE_NAME"
    print_status "Archive size: $(du -h "$ARCHIVE_NAME" | cut -f1)"
}

# Main execution
main() {
    print_status "Starting PiControl build process..."
    print_status "Target architecture: linux/$TARGET_ARCH"
    
    check_prerequisites
    clean_build
    build_frontend
    build_netssh
    create_deployment_package
    create_archive
    
    print_success "Build process completed successfully!"
    print_status "Build artifacts are in: $BUILD_DIR"
    print_status "Deployment archive created in project root"
    
    echo ""
    print_status "Next steps:"
    echo "  1. Copy the .tar.gz archive to your target machine"
    echo "  2. Extract the archive: tar -xzf picontrol-*.tar.gz"
    echo "  3. Build and deploy PiControl Helper separately using src-helper/Makefile"
    echo "  4. Run the deploy.sh script on the target machine"
}

# Run main function
main "$@"
