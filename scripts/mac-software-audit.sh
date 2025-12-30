#!/bin/bash

# Define the output file
OUTPUT_FILE="mac_software_audit.txt"

echo "Starting Mac software audit... this may take a minute."

{
    echo "=========================================================="
    echo "MAC SOFTWARE AUDIT - $(date)"
    echo "=========================================================="

    echo -e "\n[1/3] HOMEBREW FORMULAS (CLI Tools - 'Leaves' only)"
    echo "----------------------------------------------------------"
    # 'brew leaves' shows only what you installed, excluding dependencies
    brew leaves

    echo -e "\n[2/3] HOMEBREW CASKS (GUI Apps already managed by Brew)"
    echo "----------------------------------------------------------"
    brew list --cask

    echo -e "\n[3/3] POTENTIAL CASK MIGRATIONS"
    echo "The following apps are in /Applications but NOT managed by Brew."
    echo "If a match is found, add it to your Ansible 'casks' list."
    echo "----------------------------------------------------------"
    
    # Get a list of all Casks already installed to avoid duplicates
    INSTALLED_CASKS=$(brew list --cask)

    for app in /Applications/*.app; do
        app_name=$(basename "$app" .app)
        
        # Check if it's already a managed cask
        if echo "$INSTALLED_CASKS" | grep -qx "$(echo "$app_name" | tr '[:upper:]' '[:lower:]' | sed 's/ //g')"; then
            continue
        fi

        # Search Brew for a matching cask name
        # We use --desc to find more accurate matches for apps with spaces in names
        SEARCH_RESULT=$(brew search --casks "$app_name" 2>/dev/null | grep -iE "^$app_name$")
        
        if [ ! -z "$SEARCH_RESULT" ]; then
            echo "✅ MATCH FOUND: '$app_name' can be installed via cask: $SEARCH_RESULT"
        else
            echo "❌ NO CASK:     '$app_name' (Keep as manual install or check MAS)"
        fi
    done

    echo -e "\n=========================================================="
    echo "AUDIT COMPLETE"
    echo "=========================================================="
} > "$OUTPUT_FILE"

echo "Audit complete! Results saved to: $OUTPUT_FILE"