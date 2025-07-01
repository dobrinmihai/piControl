#!/bin/bash

# Exit on any error
set -e

# Check command line arguments
if [ "$1" = "--show-qr" ] || [ "$1" = "--qr" ]; then
    echo "🔐 PiControl Helper - TOTP QR Code Display"
    echo "========================================"
    
    # Source the functions we need
    function echo_error() {
        echo -e "\e[91m$1\e[0m"
    }
    
    function echo_success() {
        echo -e "\e[92m$1\e[0m"
    }
    
    function echo_info() {
        echo -e "\e[96m$1\e[0m"
    }
    
    function echo_warning() {
        echo -e "\e[93m$1\e[0m"
    }
    
    # Function to display TOTP QR code from existing configuration
    display_existing_totp_qr() {
        local config_dir="/opt/picontrol-helper/config"
        local secret_file="$config_dir/totp_secret.json"
        
        if [ ! -f "$secret_file" ]; then
            echo_warning "No existing TOTP configuration found at $secret_file"
            echo_info "Please run the full setup first: sudo $0"
            return 1
        fi
        
        echo_info "Found existing TOTP configuration, displaying QR code..."
        
        # Extract secret from JSON file
        if command -v jq &> /dev/null; then
            # Use jq if available
            SECRET=$(jq -r '.secret' "$secret_file" 2>/dev/null)
            ACCOUNT_NAME=$(jq -r '.account_name' "$secret_file" 2>/dev/null)
            ISSUER=$(jq -r '.issuer' "$secret_file" 2>/dev/null)
        else
            # Fallback to grep/sed parsing
            SECRET=$(grep '"secret"' "$secret_file" | sed 's/.*"secret"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
            ACCOUNT_NAME=$(grep '"account_name"' "$secret_file" | sed 's/.*"account_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
            ISSUER=$(grep '"issuer"' "$secret_file" | sed 's/.*"issuer"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        fi
        
        if [ -z "$SECRET" ] || [ "$SECRET" = "null" ]; then
            echo_error "Failed to extract TOTP secret from configuration file"
            return 1
        fi
        
        # Default values if not found
        [ -z "$ACCOUNT_NAME" ] || [ "$ACCOUNT_NAME" = "null" ] && ACCOUNT_NAME="PiControl@$(hostname)"
        [ -z "$ISSUER" ] || [ "$ISSUER" = "null" ] && ISSUER="PiControl Helper"
        
        # Construct TOTP URL
        TOTP_URL="otpauth://totp/${ACCOUNT_NAME}?secret=${SECRET}&issuer=${ISSUER}"
        
        echo_success "================================================"
        echo_success "📱 TOTP AUTHENTICATION QR CODE 📱"
        echo_success "================================================"
        echo_info "Account: $ACCOUNT_NAME"
        echo_info "Issuer: $ISSUER"
        echo_success "================================================"
        
        # Display QR code using qrencode
        if command -v qrencode &> /dev/null; then
            echo ""
            qrencode -t UTF8 "$TOTP_URL"
            echo ""
            echo_success "📲 Scan this QR code with your authenticator app"
            echo_info "  (Google Authenticator, Authy, Microsoft Authenticator, etc.)"
        else
            echo_warning "qrencode not found, installing it..."
            # Detect OS and install qrencode
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case $ID in
                    debian|ubuntu|pop|linuxmint)
                        apt-get update && apt-get install -y qrencode
                        ;;
                    fedora|rhel|centos)
                        dnf install -y qrencode
                        ;;
                    arch|manjaro)
                        pacman -Sy --noconfirm qrencode
                        ;;
                    *)
                        echo_warning "Unable to install qrencode automatically."
                        echo_info "Manual setup URL: $TOTP_URL"
                        return 0
                        ;;
                esac
                
                # Try again after installation
                if command -v qrencode &> /dev/null; then
                    echo ""
                    qrencode -t UTF8 "$TOTP_URL"
                    echo ""
                    echo_success "📲 Scan this QR code with your authenticator app"
                else
                    echo_info "Manual setup URL: $TOTP_URL"
                fi
            else
                echo_info "Manual setup URL: $TOTP_URL"
            fi
        fi
        
        echo_success "================================================"
        return 0
    }
    
    if display_existing_totp_qr; then
        echo_success "✅ QR code displayed successfully!"
    else
        echo_error "❌ Failed to display QR code."
        exit 1
    fi
    exit 0
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "PiControl Helper Setup Script"
    echo "============================"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h      Show this help message"
    echo "  --show-qr, --qr Display existing TOTP QR code"
    echo ""
    echo "Environment variables:"
    echo "  BUILD_FROM_SOURCE=true  Force build from source"
    echo "  USE_PREBUILT=true       Force use of prebuilt binary"
    echo "  FORCE_BUILD=true        Same as BUILD_FROM_SOURCE"
    echo ""
    echo "Examples:"
    echo "  sudo $0                 # Full setup"
    echo "  sudo $0 --show-qr       # Display QR code only"
    echo "  BUILD_FROM_SOURCE=true sudo $0  # Force source build"
    echo ""
    exit 0
fi

# Functions to output colored text
function echo_error() {
    echo -e "\e[91m$1\e[0m"
}

function echo_success() {
    echo -e "\e[92m$1\e[0m"
}

function echo_info() {
    echo -e "\e[96m$1\e[0m"
}

function echo_warning() {
    echo -e "\e[93m$1\e[0m"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo_error "Please run this script as root or with sudo"
    exit 1
fi

# Configuration variables
CURRENT_USER=$SUDO_USER
if [ -z "$CURRENT_USER" ]; then
    CURRENT_USER=$(logname 2>/dev/null || echo $USER)
fi
APP_NAME="picontrol-helper"
INSTALL_DIR="/opt/$APP_NAME"
SERVICE_NAME="$APP_NAME.service"
LOG_DIR="/var/log/$APP_NAME"
GITHUB_REPO="https://github.com/dobrinmihai/piControl.git"
TEMP_DIR="/tmp/$APP_NAME-setup"
BINARY_NAME="picontrol-helper"

echo_info "Setting up PiControl Helper for user: $CURRENT_USER"

# Detect OS and package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    DISTRO=$(uname -s)
fi

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_NAME="linux"
        ;;
    arm*)
        ARCH_NAME="linux-arm"
        ;;
    aarch64)
        ARCH_NAME="linux-arm64"
        ;;
    *)
        ARCH_NAME="unknown"
        ;;
esac

echo_info "Detected distribution: $DISTRO"
echo_info "Detected architecture: $ARCH ($ARCH_NAME)"

# Install required packages based on the distribution
echo_info "Installing required packages..."

install_packages() {
    case $DISTRO in
        debian|ubuntu|pop|linuxmint)
            apt-get update
            apt-get install -y git curl build-essential qrencode
            ;;
        fedora|rhel|centos)
            dnf install -y git curl gcc make qrencode
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm git curl base-devel qrencode
            ;;
        *)
            echo_error "Unsupported distribution: $DISTRO"
            echo_info "Please manually install: git, curl, build-essential, qrencode"
            ;;
    esac
}

# Install Go if not present
install_go() {
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version | grep -oP 'go\K[0-9]+\.[0-9]+')
        echo_info "Go is already installed (version: $GO_VERSION)"
        return 0
    fi

    echo_info "Installing Go..."

    # Determine Go architecture
    case $ARCH in
        x86_64)
            GO_ARCH="amd64"
            ;;
        arm*)
            GO_ARCH="armv6l"
            ;;
        aarch64)
            GO_ARCH="arm64"
            ;;
        *)
            echo_error "Unsupported architecture for Go: $ARCH"
            exit 1
            ;;
    esac

    GO_VERSION="1.21.5"
    GO_TARBALL="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    GO_URL="https://golang.org/dl/${GO_TARBALL}"

    cd /tmp
    if ! curl -L -o "$GO_TARBALL" "$GO_URL"; then
        echo_error "Failed to download Go. Check your internet connection"
        exit 1
    fi

    # Remove any existing Go installation
    rm -rf /usr/local/go

    # Extract Go
    tar -C /usr/local -xzf "$GO_TARBALL"

    # Add Go to PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    export PATH=$PATH:/usr/local/go/bin

    # Clean up
    rm "$GO_TARBALL"

    echo_success "Go installed successfully"
}

# Function to build from source
build_from_source() {
    echo_info "Building PiControl Helper from source..."

    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"

    # Clone the repository
    echo_info "Cloning repository from GitHub..."
    if ! git clone "$GITHUB_REPO" picontrol-repo; then
        echo_error "Failed to clone repository. Check your internet connection"
        exit 1
    fi

    cd picontrol-repo



    # Navigate to the source directory
    if [ ! -d "src-helper" ]; then
        echo_error "src-helper directory not found in repository"
        exit 1
    fi

    cd src-helper

    # Initialize Go module if go.mod doesn't exist
    if [ ! -f "go.mod" ]; then
        echo_info "Initializing Go module..."
        go mod init piControlHelper
    fi

    # Download dependencies
    echo_info "Downloading Go dependencies..."
    go mod tidy

    # Build the binary
    echo_info "Building Go binary..."
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o "$BINARY_NAME" .

    if [ ! -f "$BINARY_NAME" ]; then
        echo_error "Failed to build binary"
        exit 1
    fi

    echo_success "Binary built successfully"

    # Copy binary to installation directory
    mkdir -p "$INSTALL_DIR"
    cp "$BINARY_NAME" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"

    echo_success "Binary installed to $INSTALL_DIR/$BINARY_NAME"
}

# Function to use prebuilt binary (fallback)
use_prebuilt_binary() {
    echo_info "Looking for prebuilt binary..."

    # Try to find prebuilt binary in current directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    case $ARCH_NAME in
        linux)
            BINARY_FILE="$SCRIPT_DIR/picontrol-linux"
            ;;
        linux-arm)
            BINARY_FILE="$SCRIPT_DIR/picontrol-linux-arm"
            ;;
        *)
            echo_error "No prebuilt binary available for architecture: $ARCH_NAME"
            return 1
            ;;
    esac

    if [ -f "$BINARY_FILE" ]; then
        echo_info "Found prebuilt binary: $BINARY_FILE"
        mkdir -p "$INSTALL_DIR"
        cp "$BINARY_FILE" "$INSTALL_DIR/$BINARY_NAME"
        chmod +x "$INSTALL_DIR/$BINARY_NAME"
        echo_success "Prebuilt binary installed to $INSTALL_DIR/$BINARY_NAME"
        return 0
    else
        echo_warning "Prebuilt binary not found: $BINARY_FILE"
        return 1
    fi
}

install_packages

# Create the pkgmanagers group if it doesn't exist
if ! getent group pkgmanagers > /dev/null; then
    echo_info "Creating pkgmanagers group..."
    groupadd pkgmanagers
    echo_success "Group 'pkgmanagers' created successfully"
else
    echo_info "Group 'pkgmanagers' already exists"
fi

# Add the current user to the pkgmanagers group
if ! id -nG "$CURRENT_USER" | grep -qw "pkgmanagers"; then
    echo_info "Adding $CURRENT_USER to pkgmanagers group..."
    usermod -aG pkgmanagers "$CURRENT_USER"
    echo_success "User added to 'pkgmanagers' group"
else
    echo_info "User $CURRENT_USER is already in the pkgmanagers group"
fi

# Build the sudoers configuration based on the distribution
SUDOERS_CONF="/etc/sudoers.d/pkgmanagers"
SUDOERS_CONTENT="# Package management permissions for pkgmanagers group\n"
SUDOERS_CONTENT+="# Created by setup script on $(date)\n\n"
SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /bin/systemctl start *\n"
SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /bin/systemctl stop *\n"
SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /bin/systemctl restart *\n"
SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /bin/systemctl enable *\n"
SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /bin/systemctl disable *\n"
SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /bin/systemctl status *\n"
SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/systemctl start *\n"
SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop *\n"
SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart *\n"
SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/systemctl enable *\n"
SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/systemctl disable *\n"
SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/systemctl status *\n"

case $DISTRO in
    debian|ubuntu|pop|linuxmint)
        echo_info "Configuring for Debian/Ubuntu-based system"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/apt-get update\n"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/apt-get install *\n"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/apt-get remove *\n"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/apt update\n"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/apt install *\n"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/apt remove *\n"
        ;;
    fedora|rhel|centos)
        echo_info "Configuring for Fedora/RHEL-based system"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/dnf install *\n"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/dnf remove *\n"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/dnf update *\n"
        ;;
    arch|manjaro)
        echo_info "Configuring for Arch-based system"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/pacman -S *\n"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/pacman -R *\n"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/pacman -Syu *\n"
        ;;
    *)
        echo_info "Unknown distribution, adding common package managers"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/apt-get *\n"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/apt *\n"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/dnf *\n"
        SUDOERS_CONTENT+="%pkgmanagers ALL=(ALL) NOPASSWD: /usr/bin/pacman *\n"
        ;;
esac

# Create the sudoers file
echo -e "$SUDOERS_CONTENT" > "$SUDOERS_CONF"
chmod 440 "$SUDOERS_CONF"

echo_success "Sudoers configuration created at $SUDOERS_CONF"
echo_info "Checking sudoers syntax..."

# Check sudoers syntax
if visudo -c -f "$SUDOERS_CONF"; then
    echo_success "Sudoers syntax check passed"
else
    echo_error "Sudoers syntax check failed, removing file"
    rm -f "$SUDOERS_CONF"
    exit 1
fi

# Create installation directory and log directory
echo_info "Creating installation directory at $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"

# Try to install binary (first try building from source, then fallback to prebuilt)
echo_info "Installing PiControl Helper binary..."

# Ask user preference or set default
if [ "${BUILD_FROM_SOURCE:-}" = "true" ] || [ "${FORCE_BUILD:-}" = "true" ]; then
    echo_info "Building from source (forced)..."
    install_go
    build_from_source
elif [ "${USE_PREBUILT:-}" = "true" ]; then
    echo_info "Using prebuilt binary (forced)..."
    if ! use_prebuilt_binary; then
        echo_error "Prebuilt binary installation failed"
        exit 1
    fi
else
    # Default behavior: try prebuilt first, then build from source
    echo_info "Attempting to use prebuilt binary first..."
    if ! use_prebuilt_binary; then
        echo_warning "Prebuilt binary not available, building from source..."
        install_go
        build_from_source
    fi
fi

# Verify binary installation
if [ ! -f "$INSTALL_DIR/$BINARY_NAME" ]; then
    echo_error "Binary installation failed"
    exit 1
fi

# Create config directory for authentication
CONFIG_DIR="$INSTALL_DIR/config"
mkdir -p "$CONFIG_DIR"

# Set permissions
chown -R "$CURRENT_USER:pkgmanagers" "$INSTALL_DIR"
chmod -R 750 "$INSTALL_DIR"
chmod 750 "$CONFIG_DIR"
chown -R "$CURRENT_USER:pkgmanagers" "$LOG_DIR"
chmod -R 770 "$LOG_DIR"

# Create systemd service file
echo_info "Creating systemd service..."
cat > "/etc/systemd/system/$SERVICE_NAME" << EOL
[Unit]
Description=PiControl Helper Service
After=network.target

[Service]
User=$CURRENT_USER
Group=pkgmanagers
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/$BINARY_NAME
Restart=always
RestartSec=10
StandardOutput=append:$LOG_DIR/output.log
StandardError=append:$LOG_DIR/error.log

[Install]
WantedBy=multi-user.target
EOL

# Enable and start the service
echo_info "Enabling and starting the service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

# Create a startup script that can be run manually if needed
echo_info "Creating manual startup script..."
cat > "$INSTALL_DIR/start.sh" << EOL
#!/bin/bash
cd "$INSTALL_DIR"
./$BINARY_NAME
EOL
chmod +x "$INSTALL_DIR/start.sh"

# Create a script to check service status
cat > "$INSTALL_DIR/status.sh" << EOL
#!/bin/bash
systemctl status $SERVICE_NAME
EOL
chmod +x "$INSTALL_DIR/status.sh"

# Create a script to rebuild from source
cat > "$INSTALL_DIR/rebuild.sh" << EOL
#!/bin/bash
echo "Rebuilding PiControl Helper from source..."
cd /tmp
rm -rf picontrol-rebuild
mkdir picontrol-rebuild
cd picontrol-rebuild

git clone $GITHUB_REPO picontrol-repo
cd picontrol-repo
cd src-helper

if [ ! -f "go.mod" ]; then
    go mod init piControlHelper
fi

go mod tidy
CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o $BINARY_NAME .

if [ -f "$BINARY_NAME" ]; then
    systemctl stop $SERVICE_NAME
    cp $BINARY_NAME $INSTALL_DIR/
    chmod +x $INSTALL_DIR/$BINARY_NAME
    chown $CURRENT_USER:pkgmanagers $INSTALL_DIR/$BINARY_NAME
    systemctl start $SERVICE_NAME
    echo "Rebuild completed successfully"
else
    echo "Rebuild failed"
    exit 1
fi

cd /
rm -rf /tmp/picontrol-rebuild
EOL
chmod +x "$INSTALL_DIR/rebuild.sh"

# Clean up
echo_info "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

# Try to display existing TOTP QR code
echo_info "Checking for existing TOTP configuration..."
if display_existing_totp_qr; then
    echo_info "TOTP QR code displayed above. You can scan it with your authenticator app."
else
    echo_warning "🔑 SECURITY: Check the service logs for the TOTP QR code on first startup!"
    echo_warning "📋 View logs with: journalctl -u $SERVICE_NAME -f"
fi

echo_success "======================================================"
echo_success "PiControl Helper setup completed successfully!"
echo_success "The service is running at: http://localhost:8220"
echo_success ""
echo_success "🔐 AUTHENTICATION SETUP:"
if [ -f "/opt/picontrol-helper/config/totp_secret.json" ]; then
    echo_success "  ✅ TOTP already configured (QR code displayed above)"
    echo_success "  🔄 To display QR code again: $0 --show-qr"
else
    echo_success "  ⏳ On first startup, a TOTP QR code will be displayed"
    echo_success "  📋 Check service logs: journalctl -u $SERVICE_NAME -f"
fi
echo_success "  📱 Scan with your authenticator app (Google Authenticator, etc.)"
echo_success "  💾 Auth config saved to: /opt/picontrol-helper/config"
echo_success ""
echo_success "📱 API Authentication:"
echo_success "  1. POST /auth with TOTP code to get session"
echo_success "  2. Use session ID in Authorization header for API calls"
echo_success "  3. All /api/* endpoints require authentication"
echo_success ""
echo_success "Service management:"
echo_success "  Check status: systemctl status $SERVICE_NAME"
echo_success "  Start service: systemctl start $SERVICE_NAME"
echo_success "  Stop service: systemctl stop $SERVICE_NAME"
echo_success "  Restart service: systemctl restart $SERVICE_NAME"
echo_success ""
echo_success "Manual operations:"
echo_success "  Start manually: $INSTALL_DIR/start.sh"
echo_success "  Check status: $INSTALL_DIR/status.sh"
echo_success "  Rebuild from source: $INSTALL_DIR/rebuild.sh"
echo_success ""
echo_success "Log files are located at: $LOG_DIR"
echo_success "======================================================"
echo_info "Note: You may need to log out and log back in for the group changes to take effect"
echo_info ""
echo_info "Environment variables for installation control:"
echo_info "  BUILD_FROM_SOURCE=true - Force build from source"
echo_info "  USE_PREBUILT=true - Force use of prebuilt binary"
echo_info "  FORCE_BUILD=true - Same as BUILD_FROM_SOURCE"
echo_info ""
echo_warning "📋 View logs with: journalctl -u $SERVICE_NAME -f"
