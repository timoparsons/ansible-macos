#!/bin/bash
set -e

echo "------------------------------------------------"
echo "🖥️  PROVISIONING ORCHESTRATOR (CLI Login Mode)"
echo "------------------------------------------------"

# 1. Ensure Ansible is installed
if ! command -v ansible &>/dev/null; then
    brew install ansible
fi

# 2. User Selection
echo "Select the configuration for this Mac:"
options=("Personal" "Video Production" "Family" "Exit")
select opt in "${options[@]}"
do
    case $opt in
        "Personal") TYPE="personal"; TAGS="always,personal,video"; break ;;
        "Video Production") TYPE="work"; TAGS="always,video"; break ;;
        "Family") TYPE="family"; TAGS="always,family"; break ;;
        "Exit") exit ;;
        *) echo "invalid option $REPLY";;
    esac
done

# 3. Run the Playbook
# No --ask-vault-pass needed here!
ansible-playbook site.yml \
    -i inventory.ini \
    -K \
    --extra-vars "mac_type=$TYPE" \
    --tags "$TAGS"

# 4. Clean up for Family/Work machines if desired
if [ "$TYPE" == "family" ] || [ "$TYPE" == "work" ]; then
    echo "🧹 Security Cleanup: Logging out of GitHub..."
    gh auth logout -y
    
    if [ "$TYPE" == "family" ]; then
        echo "Removing setup files..."
        cd ~ && rm -rf "$HOME/mac-setup"
    fi
fi

echo "✅ Done!"