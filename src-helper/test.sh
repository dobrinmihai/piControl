HOST="192.168.0.152"
PORT="8220"
BASE_URL="http://$HOST:$PORT"
HEADER="Content-Type: application/json"

# Colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}==========================================================${NC}"
    echo -e "${BLUE}>>> $1${NC}"
    echo -e "${BLUE}==========================================================${NC}\n"
}

# Function to execute and display curl commands
execute_curl() {
    local description="$1"
    local method="$2"
    local endpoint="$3"
    local data="$4"

    echo -e "${YELLOW}Testing: $description${NC}"
    echo -e "${YELLOW}Endpoint: $method $endpoint${NC}"

    if [ ! -z "$data" ]; then
        echo -e "${YELLOW}Data: $data${NC}"
        response=$(curl -s -X $method -H "$HEADER" -d "$data" "$endpoint")
    else
        response=$(curl -s -X $method "$endpoint")
    fi

    # Prettify JSON if jq is available
    if command -v jq &> /dev/null; then
        echo -e "${GREEN}Response:${NC}"
        echo "$response" | jq .
    else
        echo -e "${GREEN}Response:${NC} $response"
    fi

    echo -e "${YELLOW}-------------------------------------------------------${NC}\n"
}

# Test server status
print_header "Testing Server Status"
execute_curl "Server Status" "GET" "$BASE_URL/status"

# Test package installation
print_header "Testing Package Installation"
execute_curl "Install Packages" "POST" "$BASE_URL/install" '{"packages": ["htop"]}'

# Test package search
print_header "Testing Package Search"
execute_curl "Search Packages" "GET" "$BASE_URL/search?query=htop"

# Test list installed packages
print_header "Testing List Installed Packages"
execute_curl "List Installed Packages" "GET" "$BASE_URL/list_installed"

# Test package uninstallation
print_header "Testing Package Uninstallation"
execute_curl "Uninstall Packages" "POST" "$BASE_URL/uninstall" '{"packages": ["htop"]}'

# Test list systemd services
print_header "Testing List Systemd Services"
execute_curl "List Systemd Services" "GET" "$BASE_URL/services"

# Test service status (example with ssh service)
print_header "Testing Service Status"
execute_curl "Service Status" "GET" "$BASE_URL/service/status?name=ssh"

# Test service control endpoints
print_header "Testing Service Control"
# Get services that are likely to exist
services=$(curl -s -X GET "$BASE_URL/services" | jq -r '.services[].name' 2>/dev/null | grep -v "@" | head -1)

if [ ! -z "$services" ]; then
    # Take the first service from the list
    TEST_SERVICE=$(echo $services | cut -d' ' -f1 | sed 's/\.service//')

    echo -e "${YELLOW}Using service for testing: $TEST_SERVICE${NC}\n"

    # Test status
    execute_curl "Get Service Status" "GET" "$BASE_URL/service/status?name=$TEST_SERVICE"

    # Test stop
    execute_curl "Stop Service" "POST" "$BASE_URL/service/control" '{"service": "'$TEST_SERVICE'", "action": "stop"}'

    # Test start
    execute_curl "Start Service" "POST" "$BASE_URL/service/control" '{"service": "'$TEST_SERVICE'", "action": "start"}'

    # Test restart
    execute_curl "Restart Service" "POST" "$BASE_URL/service/control" '{"service": "'$TEST_SERVICE'", "action": "restart"}'

    # Test disable
    execute_curl "Disable Service" "POST" "$BASE_URL/service/control" '{"service": "'$TEST_SERVICE'", "action": "disable"}'

    # Test enable
    execute_curl "Enable Service" "POST" "$BASE_URL/service/control" '{"service": "'$TEST_SERVICE'", "action": "enable"}'
else
    echo -e "${RED}No services found to test the service control endpoints.${NC}"
fi

print_header "Testing Completed"
echo -e "${GREEN}All endpoints have been tested.${NC}"
