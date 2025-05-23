#!/bin/bash

# Exit on any error
set -e

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
VENV_DIR="$INSTALL_DIR/venv"
SERVICE_NAME="$APP_NAME.service"
LOG_DIR="/var/log/$APP_NAME"
GITHUB_REPO=""
TEMP_DIR="/tmp/$APP_NAME-setup"

echo_info "Setting up PiControl Helper for user: $CURRENT_USER"

# Detect OS and package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    DISTRO=$(uname -s)
fi

echo_info "Detected distribution: $DISTRO"

# Install required packages based on the distribution
echo_info "Installing required packages..."

install_packages() {
    case $DISTRO in
        debian|ubuntu|pop|linuxmint)
            apt-get update
            apt-get install -y python3 python3-venv python3-pip git curl
            ;;
        fedora|rhel|centos)
            dnf install -y python3 python3-pip git curl
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm python python-pip git curl
            ;;
        *)
            echo_error "Unsupported distribution: $DISTRO"
            echo_info "Please manually install: python3, python3-venv, python3-pip, git, curl"
            ;;
    esac
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

# Create installation directory
echo_info "Creating installation directory at $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"

# Create temporary directory
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download the main.py file
echo_info "Downloading PiControl Helper application..."
if ! curl -s -o main.py "$GITHUB_REPO"; then
    echo_error "Failed to download from GitHub. Check your internet connection"
    exit 1  # This will exit the script if curl fails
fi

# Create a requirements.txt file
echo_info "Creating requirements.txt file..."
cat > requirements.txt << 'EOL'
flask==2.0.1
waitress==2.0.0
werkzeug==2.0.3
EOL

# Create Python virtual environment
echo_info "Setting up Python virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# Install requirements
echo_info "Installing Python dependencies..."
pip install -r requirements.txt

# Copy the main.py file to the installation directory
cp main.py "$INSTALL_DIR/"
chown -R "$CURRENT_USER:pkgmanagers" "$INSTALL_DIR"
chmod -R 750 "$INSTALL_DIR"
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
ExecStart=$VENV_DIR/bin/python $INSTALL_DIR/main.py
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
source "$VENV_DIR/bin/activate"
python main.py
EOL
chmod +x "$INSTALL_DIR/start.sh"

# Create a script to check service status
cat > "$INSTALL_DIR/status.sh" << EOL
#!/bin/bash
systemctl status $SERVICE_NAME
EOL
chmod +x "$INSTALL_DIR/status.sh"

# Clean up
echo_info "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo_success "======================================================"
echo_success "PiControl Helper setup completed successfully!"
echo_success "The service is running at: http://localhost:8220"
echo_success ""
echo_success "Service management:"
echo_success "  Check status: systemctl status $SERVICE_NAME"
echo_success "  Start service: systemctl start $SERVICE_NAME"
echo_success "  Stop service: systemctl stop $SERVICE_NAME"
echo_success "  Restart service: systemctl restart $SERVICE_NAME"
echo_success ""
echo_success "Log files are located at: $LOG_DIR"
echo_success "======================================================"
echo_info "Note: You may need to log out and log back in for the group changes to take effect"
