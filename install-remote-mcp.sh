#!/bin/bash

set -e

# Configuration
REQUIRED_NODE_VERSION="20.18.1"
CLAUDE_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
DEFAULT_SERVER_NAME="iam-mcp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

print_info() {
    echo "$1"
}

# Function to compare version numbers
version_ge() {
    # Returns 0 (true) if $1 >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# Check if Node.js is installed
check_node() {
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js from https://nodejs.org/ or use nvm (Node Version Manager)"
        print_info "To install with nvm: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
        exit 1
    fi
}

# Check and upgrade Node.js version if needed
check_node_version() {
    local current_version
    current_version=$(node --version | sed 's/v//')

    print_info "Current Node.js version: $current_version"
    print_info "Required Node.js version: $REQUIRED_NODE_VERSION or higher"

    if version_ge "$current_version" "$REQUIRED_NODE_VERSION"; then
        print_success "Node.js version is sufficient."
    else
        print_warning "Node.js version is too old."

        # Check if nvm is available
        if command -v nvm &> /dev/null || [ -s "$HOME/.nvm/nvm.sh" ]; then
            # Load nvm if it's not already loaded
            if ! command -v nvm &> /dev/null; then
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            fi

            print_info "nvm detected. Installing Node.js version 20..."
            nvm install 20
            nvm use 20
            local new_version
            new_version=$(node --version | sed 's/v//')
            print_success "Node.js upgraded to version $new_version"
        else
            print_error "Node.js version $current_version is below required version $REQUIRED_NODE_VERSION"
            print_info "Please upgrade Node.js manually:"
            print_info "  Option 1: Install from https://nodejs.org/"
            print_info "  Option 2: Install nvm and run this script again"
            print_info "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
            exit 1
        fi
    fi
}

# Check if jq is installed, if not use python for JSON parsing
check_json_tool() {
    if command -v jq &> /dev/null; then
        return 0
    else
        if ! command -v python3 &> /dev/null; then
            print_error "Neither jq nor python3 is available. Please install jq: brew install jq"
            exit 1
        fi
    fi
}

# Parse JSON using jq or python
parse_json() {
    local json_file="$1"
    local query="$2"

    if command -v jq &> /dev/null; then
        jq -r "$query" "$json_file"
    else
        python3 -c "import json, sys; data=json.load(open('$json_file')); print($query)"
    fi
}

# Add server to Claude config
add_server_to_config() {
    local server_name="$1"
    local server_url="$2"

    python3 << EOF
import json
import sys

config_file = "$CLAUDE_CONFIG"

# Read existing config or create new one
try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except FileNotFoundError:
    config = {}

# Ensure mcpServers key exists
if 'mcpServers' not in config:
    config['mcpServers'] = {}

# Add new server
config['mcpServers']['$server_name'] = {
    'command': 'npx',
    'args': ['-y', 'mcp-remote', '$server_url', '--debug']
}

# Write back to file
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("Success")
EOF
}

# Check for duplicate URL or server name
check_duplicates() {
    local server_url="$1"
    local server_name="$2"

    if [ ! -f "$CLAUDE_CONFIG" ]; then
        return 0
    fi

    python3 << EOF
import json
import sys

config_file = "$CLAUDE_CONFIG"

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except FileNotFoundError:
    sys.exit(0)

if 'mcpServers' not in config:
    sys.exit(0)

# Check for duplicate URL
for name, server_config in config['mcpServers'].items():
    if 'args' in server_config:
        # Find the URL in args (it comes after 'mcp-remote')
        args = server_config['args']
        try:
            mcp_remote_idx = args.index('mcp-remote')
            if mcp_remote_idx + 1 < len(args):
                existing_url = args[mcp_remote_idx + 1]
                if existing_url == '$server_url':
                    print(f"DUPLICATE_URL:{name}")
                    sys.exit(1)
        except ValueError:
            pass

# Check for duplicate server name
if '$server_name' in config['mcpServers']:
    print("DUPLICATE_NAME")
    sys.exit(2)

sys.exit(0)
EOF

    return $?
}

# Prompt user for input
prompt_user() {
    local prompt="$1"
    local response
    read -p "$prompt" response
    echo "$response"
}

# Main script
main() {
    print_info "=== Remote MCP Server Installer ==="
    echo

    # Check if URL argument is provided
    if [ $# -eq 0 ]; then
        print_error "Usage: $0 <mcp-server-url> [server-name]"
        print_info "Example: $0 https://mcp-dev.pionexdev.com/mcp"
        exit 1
    fi

    local server_url="$1"
    local server_name="${2:-$DEFAULT_SERVER_NAME}"

    print_info "MCP Server URL: $server_url"
    print_info "Server Name: $server_name"
    echo

    # Step 1: Check Node.js installation
    print_info "Step 1: Checking Node.js installation..."
    check_node

    # Step 2: Check Node.js version
    print_info "Step 2: Checking Node.js version..."
    check_node_version
    echo

    # Step 3: Check JSON parsing tool
    print_info "Step 3: Checking JSON parsing tools..."
    check_json_tool
    echo

    # Step 4: Check for duplicates
    print_info "Step 4: Checking for duplicate configurations..."

    # Disable exit on error for duplicate check
    set +e
    local duplicate_output
    duplicate_output=$(check_duplicates "$server_url" "$server_name" 2>&1)
    local duplicate_status=$?
    set -e

    if [ $duplicate_status -eq 1 ]; then
        # Duplicate URL found
        local existing_name=$(echo "$duplicate_output" | grep "DUPLICATE_URL:" | cut -d: -f2)
        print_warning "A server with URL '$server_url' already exists with name '$existing_name'."
        local choice
        choice=$(prompt_user "Do you want to (a)dd another one with same URL but different name, enter (n)ew URL, or (e)xit? [a/n/e]: ")

        if [[ "$choice" == "a" || "$choice" == "A" ]]; then
            # Prompt for new name
            while true; do
                local new_name
                new_name=$(prompt_user "Enter a new server name: ")
                if [ -z "$new_name" ]; then
                    print_error "Server name cannot be empty."
                    continue
                fi

                set +e
                check_duplicates "$server_url" "$new_name"
                local name_status=$?
                set -e

                if [ $name_status -eq 2 ]; then
                    print_error "Server name '$new_name' already exists. Please choose another name."
                    continue
                fi

                server_name="$new_name"
                break
            done
        elif [[ "$choice" == "n" || "$choice" == "N" ]]; then
            # Prompt for new URL
            while true; do
                local new_url
                new_url=$(prompt_user "Enter a new MCP server URL: ")
                if [ -z "$new_url" ]; then
                    print_error "URL cannot be empty."
                    continue
                fi

                set +e
                local url_check_output
                url_check_output=$(check_duplicates "$new_url" "$server_name" 2>&1)
                local check_status=$?
                set -e

                if [ $check_status -eq 1 ]; then
                    local existing=$(echo "$url_check_output" | grep "DUPLICATE_URL:" | cut -d: -f2)
                    print_error "This URL already exists with name '$existing'. Please enter a different URL."
                    continue
                elif [ $check_status -eq 2 ]; then
                    # Name conflict with new URL, prompt for new name
                    print_warning "Server name '$server_name' already exists."
                    local new_name
                    new_name=$(prompt_user "Enter a new server name: ")
                    if [ -z "$new_name" ]; then
                        print_error "Server name cannot be empty."
                        continue
                    fi
                    server_name="$new_name"
                fi

                server_url="$new_url"
                break
            done
        else
            print_info "Installation cancelled."
            exit 0
        fi
    elif [ $duplicate_status -eq 2 ]; then
        # Duplicate server name found
        print_warning "A server with name '$server_name' already exists."
        local choice
        choice=$(prompt_user "Do you want to (r)ename it or (e)xit? [r/e]: ")

        if [[ "$choice" != "r" && "$choice" != "R" ]]; then
            print_info "Installation cancelled."
            exit 0
        fi

        # Prompt for new name
        while true; do
            local new_name
            new_name=$(prompt_user "Enter a new server name: ")
            if [ -z "$new_name" ]; then
                print_error "Server name cannot be empty."
                continue
            fi

            set +e
            check_duplicates "$server_url" "$new_name"
            local rename_status=$?
            set -e

            if [ $rename_status -eq 2 ]; then
                print_error "Server name '$new_name' already exists. Please choose another name."
                continue
            fi

            server_name="$new_name"
            break
        done
    fi

    print_success "No conflicts found."
    echo

    # Step 5: Create config directory if it doesn't exist
    print_info "Step 5: Ensuring Claude config directory exists..."
    local config_dir
    config_dir=$(dirname "$CLAUDE_CONFIG")
    mkdir -p "$config_dir"
    echo

    # Step 6: Add server to config
    print_info "Step 6: Adding server to Claude Desktop configuration..."
    add_server_to_config "$server_name" "$server_url"

    if [ $? -eq 0 ]; then
        print_success "Successfully added server '$server_name' to Claude Desktop!"
        echo
        print_info "Configuration added to: $CLAUDE_CONFIG"
        print_info ""
        print_info "Next steps:"
        print_info "1. Restart Claude Desktop application"
        print_info "2. The MCP server '$server_name' should now be available"
        print_info "3. Test the connection by asking Claude to use the MCP tools"
    else
        print_error "Failed to add server to configuration."
        exit 1
    fi
}

# Run main function
main "$@"
