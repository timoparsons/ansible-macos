#!/bin/bash
# ============================================================================
# discover-app-files.sh
# Find all files/folders related to a macOS application
# Usage: ./discover-app-files.sh "App Name"
# Example: ./discover-app-files.sh "Strongbox"
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if app name provided
if [ -z "$1" ]; then
    echo "Usage: $0 \"App Name\""
    echo "Example: $0 \"Strongbox\""
    exit 1
fi

APP_NAME="$1"
OUTPUT_FILE="app-discovery-${APP_NAME// /-}.txt"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}App File Discovery: ${APP_NAME}${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Function to print section header
print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to find and display files
find_and_display() {
    local path="$1"
    local pattern="$2"
    local description="$3"
    
    if [ ! -d "$path" ]; then
        echo -e "${YELLOW}⚠️  Directory not found: $path${NC}"
        return
    fi
    
    local results=$(find "$path" -maxdepth 1 -iname "*$pattern*" 2>/dev/null)
    
    if [ -z "$results" ]; then
        echo -e "${YELLOW}✗ No matches found${NC}"
    else
        echo -e "${GREEN}✓ Found matches:${NC}"
        echo "$results" | while read -r item; do
            if [ -f "$item" ]; then
                local size=$(ls -lh "$item" | awk '{print $5}')
                echo -e "  ${GREEN}[FILE]${NC} $item (${size})"
            elif [ -d "$item" ]; then
                local count=$(find "$item" -type f 2>/dev/null | wc -l | tr -d ' ')
                echo -e "  ${CYAN}[DIR]${NC}  $item (${count} files)"
            fi
        done
    fi
}

# Start output file
{
    echo "========================================="
    echo "App File Discovery: $APP_NAME"
    echo "Generated: $(date)"
    echo "========================================="
    echo ""

    # ========================================================================
    # 1. FIND THE APP BUNDLE
    # ========================================================================
    print_section "1. Application Bundle"
    
    APP_PATH=$(find /Applications -maxdepth 1 -iname "*${APP_NAME}*.app" 2>/dev/null | head -n 1)
    
    if [ -z "$APP_PATH" ]; then
        echo -e "${RED}✗ Application not found in /Applications/${NC}"
        echo "Application not found in /Applications/" | tee -a "$OUTPUT_FILE"
        
        # Check user Applications
        USER_APP_PATH=$(find ~/Applications -maxdepth 1 -iname "*${APP_NAME}*.app" 2>/dev/null | head -n 1)
        if [ -n "$USER_APP_PATH" ]; then
            APP_PATH="$USER_APP_PATH"
            echo -e "${GREEN}✓ Found in ~/Applications: $APP_PATH${NC}"
            echo "Found in ~/Applications: $APP_PATH" | tee -a "$OUTPUT_FILE"
        fi
    else
        echo -e "${GREEN}✓ Found: $APP_PATH${NC}"
        echo "Found: $APP_PATH" | tee -a "$OUTPUT_FILE"
    fi
    
    # Get bundle identifier
    if [ -n "$APP_PATH" ]; then
        BUNDLE_ID=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleIdentifier 2>/dev/null)
        if [ -n "$BUNDLE_ID" ]; then
            echo -e "${GREEN}✓ Bundle ID: $BUNDLE_ID${NC}"
            echo "Bundle ID: $BUNDLE_ID" | tee -a "$OUTPUT_FILE"
        fi
    fi
    
    echo ""

    # ========================================================================
    # 2. PREFERENCES
    # ========================================================================
    print_section "2. Preferences (~/Library/Preferences)"
    echo "Location: ~/Library/Preferences" | tee -a "$OUTPUT_FILE"
    echo "Searching for: *${APP_NAME}* and *${BUNDLE_ID}*" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    find_and_display ~/Library/Preferences "$APP_NAME" "by app name" | tee -a "$OUTPUT_FILE"
    
    if [ -n "$BUNDLE_ID" ]; then
        echo "" | tee -a "$OUTPUT_FILE"
        find_and_display ~/Library/Preferences "$BUNDLE_ID" "by bundle ID" | tee -a "$OUTPUT_FILE"
    fi

    # ========================================================================
    # 3. APPLICATION SUPPORT
    # ========================================================================
    print_section "3. Application Support (~/Library/Application Support)"
    echo "Location: ~/Library/Application Support" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    find_and_display ~/Library/Application\ Support "$APP_NAME" "by app name" | tee -a "$OUTPUT_FILE"
    
    if [ -n "$BUNDLE_ID" ]; then
        echo "" | tee -a "$OUTPUT_FILE"
        find_and_display ~/Library/Application\ Support "$BUNDLE_ID" "by bundle ID" | tee -a "$OUTPUT_FILE"
    fi

    # ========================================================================
    # 4. CONTAINERS (Sandboxed Apps)
    # ========================================================================
    print_section "4. Containers (~/Library/Containers) - Sandboxed Apps"
    echo "Location: ~/Library/Containers" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    find_and_display ~/Library/Containers "$APP_NAME" "by app name" | tee -a "$OUTPUT_FILE"
    
    if [ -n "$BUNDLE_ID" ]; then
        echo "" | tee -a "$OUTPUT_FILE"
        find_and_display ~/Library/Containers "$BUNDLE_ID" "by bundle ID" | tee -a "$OUTPUT_FILE"
    fi

    # ========================================================================
    # 5. GROUP CONTAINERS (Shared with Extensions)
    # ========================================================================
    print_section "5. Group Containers (~/Library/Group Containers) - App + Extensions"
    echo "Location: ~/Library/Group Containers" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    find_and_display ~/Library/Group\ Containers "$APP_NAME" "by app name" | tee -a "$OUTPUT_FILE"
    
    if [ -n "$BUNDLE_ID" ]; then
        echo "" | tee -a "$OUTPUT_FILE"
        # Try finding group containers related to bundle ID
        local group_pattern=$(echo "$BUNDLE_ID" | sed 's/com\./group\./')
        find_and_display ~/Library/Group\ Containers "$group_pattern" "by group bundle ID" | tee -a "$OUTPUT_FILE"
    fi

    # ========================================================================
    # 6. CACHES (Usually skip these in backups)
    # ========================================================================
    print_section "6. Caches (~/Library/Caches) - Usually SKIP in backups"
    echo "Location: ~/Library/Caches" | tee -a "$OUTPUT_FILE"
    echo "⚠️  Generally exclude these from backups" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    find_and_display ~/Library/Caches "$APP_NAME" "by app name" | tee -a "$OUTPUT_FILE"
    
    if [ -n "$BUNDLE_ID" ]; then
        echo "" | tee -a "$OUTPUT_FILE"
        find_and_display ~/Library/Caches "$BUNDLE_ID" "by bundle ID" | tee -a "$OUTPUT_FILE"
    fi

    # ========================================================================
    # 7. SAVED APPLICATION STATE (Usually skip)
    # ========================================================================
    print_section "7. Saved Application State - Usually SKIP in backups"
    echo "Location: ~/Library/Saved Application State" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    if [ -n "$BUNDLE_ID" ]; then
        find_and_display ~/Library/Saved\ Application\ State "$BUNDLE_ID" "by bundle ID" | tee -a "$OUTPUT_FILE"
    fi

    # ========================================================================
    # 8. LOGS (Usually skip)
    # ========================================================================
    print_section "8. Logs (~/Library/Logs) - Usually SKIP in backups"
    echo "Location: ~/Library/Logs" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    find_and_display ~/Library/Logs "$APP_NAME" "by app name" | tee -a "$OUTPUT_FILE"

    # ========================================================================
    # 9. DEEP SEARCH (More thorough but slower)
    # ========================================================================
    print_section "9. Deep Search in ~/Library (May take a moment...)"
    echo "Searching entire ~/Library for any matches..." | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    echo "By app name:" | tee -a "$OUTPUT_FILE"
    find ~/Library -iname "*$APP_NAME*" -maxdepth 3 2>/dev/null | head -n 20 | while read -r item; do
        if [ -f "$item" ]; then
            echo "  [FILE] $item" | tee -a "$OUTPUT_FILE"
        elif [ -d "$item" ]; then
            echo "  [DIR]  $item" | tee -a "$OUTPUT_FILE"
        fi
    done
    
    if [ -n "$BUNDLE_ID" ]; then
        echo "" | tee -a "$OUTPUT_FILE"
        echo "By bundle ID:" | tee -a "$OUTPUT_FILE"
        find ~/Library -iname "*$BUNDLE_ID*" -maxdepth 3 2>/dev/null | head -n 20 | while read -r item; do
            if [ -f "$item" ]; then
                echo "  [FILE] $item" | tee -a "$OUTPUT_FILE"
            elif [ -d "$item" ]; then
                echo "  [DIR]  $item" | tee -a "$OUTPUT_FILE"
            fi
        done
    fi

    # ========================================================================
    # 10. DETAILED FILE INSPECTION (for found containers/groups)
    # ========================================================================
    print_section "10. Inspecting Important Directories"
    
    # Check Containers
    if [ -d ~/Library/Containers/"$BUNDLE_ID" ]; then
        echo "Container structure:" | tee -a "$OUTPUT_FILE"
        echo "~/Library/Containers/$BUNDLE_ID" | tee -a "$OUTPUT_FILE"
        find ~/Library/Containers/"$BUNDLE_ID" -type f -name "*.plist" 2>/dev/null | head -10 | while read -r plist; do
            echo "  Found plist: $plist" | tee -a "$OUTPUT_FILE"
        done
        echo "" | tee -a "$OUTPUT_FILE"
    fi
    
    # Check Group Containers
    GROUP_CONTAINER=$(find ~/Library/Group\ Containers -maxdepth 1 -iname "*$APP_NAME*" -o -iname "*group.$(echo $BUNDLE_ID | sed 's/^com\.//')*" 2>/dev/null | head -n 1)
    
    if [ -n "$GROUP_CONTAINER" ]; then
        echo "Group Container structure:" | tee -a "$OUTPUT_FILE"
        echo "$GROUP_CONTAINER" | tee -a "$OUTPUT_FILE"
        echo "" | tee -a "$OUTPUT_FILE"
        
        # List directory structure
        find "$GROUP_CONTAINER" -maxdepth 2 -type d 2>/dev/null | while read -r dir; do
            local count=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
            if [ "$count" -gt 0 ]; then
                echo "  [DIR] $dir ($count files)" | tee -a "$OUTPUT_FILE"
            fi
        done
        
        echo "" | tee -a "$OUTPUT_FILE"
        echo "Sample files in Group Container:" | tee -a "$OUTPUT_FILE"
        
        # Show some actual file contents to understand structure
        find "$GROUP_CONTAINER" -type f ! -name "*.sqlite*" ! -name "*.db" 2>/dev/null | head -5 | while read -r file; do
            echo "" | tee -a "$OUTPUT_FILE"
            echo "  File: ${file/$HOME/~}" | tee -a "$OUTPUT_FILE"
            echo "  Size: $(ls -lh "$file" | awk '{print $5}')" | tee -a "$OUTPUT_FILE"
            
            # Try to read as plist
            if plutil -p "$file" >/dev/null 2>&1; then
                echo "  Type: Binary plist" | tee -a "$OUTPUT_FILE"
                echo "  Sample content:" | tee -a "$OUTPUT_FILE"
                plutil -p "$file" 2>/dev/null | head -20 | sed 's/^/    /' | tee -a "$OUTPUT_FILE"
            elif file "$file" | grep -q "JSON\|text"; then
                echo "  Type: $(file -b "$file")" | tee -a "$OUTPUT_FILE"
                echo "  Sample content:" | tee -a "$OUTPUT_FILE"
                head -20 "$file" 2>/dev/null | sed 's/^/    /' | tee -a "$OUTPUT_FILE"
            else
                echo "  Type: $(file -b "$file")" | tee -a "$OUTPUT_FILE"
            fi
        done
        echo "" | tee -a "$OUTPUT_FILE"
    fi

    # ========================================================================
    # 11. RECOMMENDED BACKUP YAML
    # ========================================================================
    print_section "11. Recommended Backup Configuration (YAML)"
    echo "Add this to vars/app_backups.yml:" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    cat <<EOF | tee -a "$OUTPUT_FILE"
  ${APP_NAME,,}:
    name: "$APP_NAME"
    paths:
      # Review findings above and add paths like:
      # 
      # For PREFERENCES (files):
      # - src: "~/Library/Preferences/com.example.app.plist"
      #   dest: "${APP_NAME,,}/preferences/com.example.app.plist"
      #
      # For APPLICATION SUPPORT (directories):
      # - src: "~/Library/Application Support/$APP_NAME"
      #   dest: "${APP_NAME,,}/application-support"
      #   exclude:
      #     - "Cache"
      #     - "Logs"
      #
      # For CONTAINERS (sandboxed apps):
      # - src: "~/Library/Containers/$BUNDLE_ID/Data/Library/Preferences/$BUNDLE_ID.plist"
      #   dest: "${APP_NAME,,}/preferences/main.plist"
      #
      # For GROUP CONTAINERS (shared data):
      # - src: "~/Library/Group Containers/group.example.app"
      #   dest: "${APP_NAME,,}/group-container"
EOF

    echo "" | tee -a "$OUTPUT_FILE"

    # ========================================================================
    # SUMMARY
    # ========================================================================
    print_section "Summary & Next Steps"
    
    cat <<EOF | tee -a "$OUTPUT_FILE"
${GREEN}✓ Discovery complete!${NC}

${YELLOW}Next Steps:${NC}
1. Review the findings above
2. Identify which files/folders contain USER SETTINGS (not caches/logs)
3. Test by changing settings in the app, then checking which files changed:
   
   ${CYAN}# Before making changes:${NC}
   find ~/Library -iname "*$APP_NAME*" -newer /tmp/timestamp 2>/dev/null
   
   ${CYAN}# Create timestamp:${NC}
   touch /tmp/timestamp
   
   ${CYAN}# Make changes in the app, then find what changed:${NC}
   find ~/Library -iname "*$APP_NAME*" -newer /tmp/timestamp 2>/dev/null

4. Add the essential paths to vars/app_backups.yml
5. Test backup/restore on a test machine or VM

${YELLOW}Common Patterns:${NC}
- Preferences: Usually just .plist files
- Application Support: Config files, user data, plugins
- Containers: Full sandboxed app data (check Data/Library subdirs)
- Group Containers: Shared data between app and extensions

${YELLOW}Usually EXCLUDE:${NC}
- Cache, Caches, cache directories
- Logs, logs directories  
- Temporary files
- Downloaded content that can be re-downloaded
- Database indexes that regenerate

Full results saved to: ${GREEN}$OUTPUT_FILE${NC}
EOF

} | tee /dev/tty

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Full results saved to: $OUTPUT_FILE${NC}"
echo -e "${GREEN}========================================${NC}"