#!/bin/bash

# PiControl Helper Authentication Example Client
# This script demonstrates how to authenticate and use the API

set -e

# Configuration
SERVER_URL="http://192.168.1.72:8220"
TOTP_CODE=""
SESSION_FILE="/tmp/picontrol_session"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions for colored output
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to check if server is running
check_server() {
    print_info "Checking if PiControl Helper is running..."
    if curl -s "$SERVER_URL/status" > /dev/null; then
        print_success "Server is running"
        return 0
    else
        print_error "Server is not running or not accessible at $SERVER_URL"
        return 1
    fi
}

# Function to get authentication status
get_auth_status() {
    print_info "Getting authentication status..."
    curl -s "$SERVER_URL/auth/status" | jq .
}

# Function to authenticate with TOTP
authenticate() {
    if [ -z "$TOTP_CODE" ]; then
        echo -n "Enter TOTP code from your authenticator app: "
        read -r TOTP_CODE
    fi

    print_info "Authenticating with TOTP code: $TOTP_CODE"

    RESPONSE=$(curl -s -X POST "$SERVER_URL/auth" \
        -H "Content-Type: application/json" \
        -d "{\"totp_code\":\"$TOTP_CODE\"}")

    SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

    if [ "$SUCCESS" = "true" ]; then
        SESSION_ID=$(echo "$RESPONSE" | jq -r '.session_id')
        EXPIRES_AT=$(echo "$RESPONSE" | jq -r '.expires_at')

        # Save session to file
        echo "$SESSION_ID" > "$SESSION_FILE"

        print_success "Authentication successful!"
        print_info "Session ID: ${SESSION_ID:0:16}..."
        print_info "Expires at: $EXPIRES_AT"
        print_info "Session saved to: $SESSION_FILE"
    else
        MESSAGE=$(echo "$RESPONSE" | jq -r '.message')
        print_error "Authentication failed: $MESSAGE"
        return 1
    fi
}

# Function to load session from file
load_session() {
    if [ -f "$SESSION_FILE" ]; then
        SESSION_ID=$(cat "$SESSION_FILE")
        print_info "Loaded session from file: ${SESSION_ID:0:16}..."
        return 0
    else
        print_warning "No saved session found"
        return 1
    fi
}

# Function to make authenticated API calls
api_call() {
    local method="$1"
    local endpoint="$2"
    local data="$3"

    if [ -z "$SESSION_ID" ]; then
        if ! load_session; then
            print_error "No valid session. Please authenticate first."
            return 1
        fi
    fi

    local curl_cmd="curl -s -X $method"
    curl_cmd="$curl_cmd -H 'Authorization: Bearer $SESSION_ID'"

    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        curl_cmd="$curl_cmd -H 'Content-Type: application/json'"
        curl_cmd="$curl_cmd -d '$data'"
    fi

    curl_cmd="$curl_cmd $SERVER_URL/api$endpoint"

    print_info "Making API call: $method /api$endpoint"
    eval "$curl_cmd"
}

# Function to search packages
search_packages() {
    local query="$1"
    if [ -z "$query" ]; then
        echo -n "Enter package name to search: "
        read -r query
    fi

    print_info "Searching for packages matching: $query"
    api_call "GET" "/search?query=$query" | jq .
}

# Function to install packages
install_packages() {
    local packages="$1"
    if [ -z "$packages" ]; then
        echo -n "Enter package names to install (space-separated): "
        read -r packages
    fi

    # Convert space-separated list to JSON array
    local json_packages=$(echo "$packages" | tr ' ' '\n' | jq -R . | jq -s .)
    local data="{\"packages\":$json_packages}"

    print_info "Installing packages: $packages"
    api_call "POST" "/install" "$data" | jq .
}

# Function to list installed packages
list_installed() {
    print_info "Listing installed packages..."
    api_call "GET" "/list_installed" | jq .
}

# Function to list services
list_services() {
    print_info "Listing system services..."
    api_call "GET" "/services" | jq .
}

# Function to get service status
service_status() {
    local service="$1"
    if [ -z "$service" ]; then
        echo -n "Enter service name: "
        read -r service
    fi

    print_info "Getting status for service: $service"
    api_call "GET" "/service/status?name=$service" | jq .
}

# Function to control service
control_service() {
    local service="$1"
    local action="$2"

    if [ -z "$service" ]; then
        echo -n "Enter service name: "
        read -r service
    fi

    if [ -z "$action" ]; then
        echo -n "Enter action (start/stop/restart/enable/disable): "
        read -r action
    fi

    local data="{\"service\":\"$service\",\"action\":\"$action\"}"

    print_info "Performing $action on service: $service"
    api_call "POST" "/service/control" "$data" | jq .
}

# Function to check session status
session_status() {
    if [ -z "$SESSION_ID" ]; then
        if ! load_session; then
            print_error "No active session found"
            return 1
        fi
    fi

    print_info "Checking session status..."
    RESPONSE=$(curl -s -X GET "$SERVER_URL/api/auth/session" \
        -H "Authorization: Bearer $SESSION_ID")

    # Check if the response contains an error
    ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
    if [ -n "$ERROR" ]; then
        print_error "Session error: $ERROR"
        # Remove invalid session file
        rm -f "$SESSION_FILE"
        SESSION_ID=""
        return 1
    else
        echo "$RESPONSE" | jq .
        return 0
    fi
}

# Function to logout
logout() {
    if [ -z "$SESSION_ID" ]; then
        if ! load_session; then
            print_warning "No active session to logout"
            return 0
        fi
    fi

    print_info "Logging out..."
    curl -s -X POST "$SERVER_URL/api/auth/logout" \
        -H "Authorization: Bearer $SESSION_ID" | jq .

    # Remove session file
    rm -f "$SESSION_FILE"
    SESSION_ID=""
    print_success "Logged out successfully"
}

# Function to show usage
show_usage() {
    echo "PiControl Helper Client Example"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  check              - Check if server is running"
    echo "  status             - Get authentication status"
    echo "  auth [totp_code]   - Authenticate with TOTP code"
    echo "  session            - Check current session status"
    echo "  search [query]     - Search for packages"
    echo "  install [packages] - Install packages"
    echo "  list               - List installed packages"
    echo "  services           - List system services"
    echo "  service-status [name] - Get service status"
    echo "  service-control [name] [action] - Control service"
    echo "  logout             - Logout and clear session"
    echo "  interactive        - Interactive mode"
    echo ""
    echo "Examples:"
    echo "  $0 auth 123456"
    echo "  $0 session"
    echo "  $0 search htop"
    echo "  $0 install \"htop curl\""
    echo "  $0 service-status ssh"
    echo "  $0 service-control ssh restart"
}

# Interactive mode
interactive_mode() {
    echo "🚀 PiControl Helper Interactive Client"
    echo "Type 'help' for available commands, 'quit' to exit"
    echo ""

    while true; do
        echo -n "picontrol> "
        read -r cmd args

        case "$cmd" in
            "help")
                echo "Available commands:"
                echo "  auth [code]     - Authenticate"
                echo "  session         - Check session status"
                echo "  search [query]  - Search packages"
                echo "  install [pkgs]  - Install packages"
                echo "  list           - List installed packages"
                echo "  services       - List services"
                echo "  status [name]  - Service status"
                echo "  control [name] [action] - Control service"
                echo "  logout         - Logout"
                echo "  quit           - Exit"
                ;;
            "auth")
                TOTP_CODE="$args"
                authenticate
                ;;
            "session")
                session_status
                ;;
            "search")
                search_packages "$args"
                ;;
            "install")
                install_packages "$args"
                ;;
            "list")
                list_installed
                ;;
            "services")
                list_services
                ;;
            "status")
                service_status "$args"
                ;;
            "control")
                set -- $args
                control_service "$1" "$2"
                ;;
            "logout")
                logout
                ;;
            "quit"|"exit")
                print_info "Goodbye!"
                break
                ;;
            "")
                continue
                ;;
            *)
                print_error "Unknown command: $cmd"
                ;;
        esac
        echo ""
    done
}

# Main script logic
main() {
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed. Please install jq first."
        exit 1
    fi

    case "${1:-}" in
        "check")
            check_server
            ;;
        "status")
            get_auth_status
            ;;
        "auth")
            TOTP_CODE="$2"
            check_server && authenticate
            ;;
        "session")
            check_server && session_status
            ;;
        "search")
            check_server && search_packages "$2"
            ;;
        "install")
            check_server && install_packages "$2"
            ;;
        "list")
            check_server && list_installed
            ;;
        "services")
            check_server && list_services
            ;;
        "service-status")
            check_server && service_status "$2"
            ;;
        "service-control")
            check_server && control_service "$2" "$3"
            ;;
        "logout")
            logout
            ;;
        "interactive")
            check_server && interactive_mode
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        "")
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
