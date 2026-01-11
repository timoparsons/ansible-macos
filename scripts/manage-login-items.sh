#!/bin/bash
# scripts/manage-login-items.sh
# Helper script to manually add/remove/list login items

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

show_help() {
    cat << EOF
Usage: $0 [command] [options]

Commands:
    list                    List all current login items
    add <app-name>          Add an app to login items
    add-hidden <app-name>   Add an app to login items (hidden)
    remove <app-name>       Remove an app from login items
    
Examples:
    $0 list
    $0 add Raycast
    $0 add-hidden "Carbon Copy Cloner"
    $0 remove Raycast

EOF
}

list_login_items() {
    echo -e "${GREEN}Current Login Items:${NC}"
    osascript -e 'tell application "System Events" to get the name of every login item' | tr ',' '\n' | sed 's/^ /  - /'
}

add_login_item() {
    local app_name="$1"
    local hidden="${2:-false}"
    
    # Find the app
    local app_path=$(find /Applications ~/Applications -maxdepth 1 -name "${app_name}.app" 2>/dev/null | head -n 1)
    
    if [ -z "$app_path" ]; then
        echo -e "${RED}Error: ${app_name}.app not found in /Applications${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Adding ${app_name} to login items (hidden: ${hidden})...${NC}"
    osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"${app_path}\", hidden:${hidden}}"
    echo -e "${GREEN}✓ Added ${app_name}${NC}"
}

remove_login_item() {
    local app_name="$1"
    
    echo -e "${YELLOW}Removing ${app_name} from login items...${NC}"
    osascript -e "tell application \"System Events\" to delete login item \"${app_name}\"" 2>/dev/null || {
        echo -e "${RED}Error: ${app_name} not found in login items${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ Removed ${app_name}${NC}"
}

# Main logic
case "${1:-}" in
    list)
        list_login_items
        ;;
    add)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: App name required${NC}"
            show_help
            exit 1
        fi
        add_login_item "$2" "false"
        ;;
    add-hidden)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: App name required${NC}"
            show_help
            exit 1
        fi
        add_login_item "$2" "true"
        ;;
    remove)
        if [ -z "$2" ]; then
            echo -e "${RED}Error: App name required${NC}"
            show_help
            exit 1
        fi
        remove_login_item "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Error: Unknown command${NC}"
        show_help
        exit 1
        ;;
esac