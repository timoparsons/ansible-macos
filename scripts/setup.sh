#!/bin/bash

# Exit on error
set -e

# Get script directory and navigate to repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
cd "$REPO_ROOT"

# Verify Ansible files exist
if [ ! -f "site.yml" ] || [ ! -f "inventory.ini" ]; then
    echo "❌ Required Ansible files not found in $REPO_ROOT"
    exit 1
fi

echo "🔍 Verifying sudo permissions..."
if sudo -n true 2>/dev/null; then
    echo "✅ Passwordless sudo is active."
else
    echo "❌ Passwordless sudo is NOT configured. This is required for Cask installers."
    echo "   Please run bootstrap.sh again or check /etc/sudoers.d/$USER"
    exit 1
fi

# Clear screen for a clean start
clear

echo "===================================================="
echo "🖥️  macOS Provisioning Orchestrator"
echo "===================================================="
echo ""

# Install Ansible if missing (Homebrew is already there from Gist)
if ! command -v ansible &>/dev/null; then
    echo "📦 Installing Ansible..."
    if ! brew install ansible; then
        echo "❌ Failed to install Ansible. Exiting."
        exit 1
    fi
fi


# Install required Ansible Galaxy collections and roles
if [ -f "requirements.yml" ]; then
    echo "📦 Installing Ansible Galaxy dependencies..."
    # Install collections
    if ! ansible-galaxy collection install -r requirements.yml; then
        echo "❌ Failed to install Galaxy collections. Exiting."
        exit 1
    fi
    # Install roles (if any are defined)
    if ! ansible-galaxy role install -r requirements.yml 2>/dev/null; then
        # Ignore error if no roles are defined
        true
    fi
    echo ""
fi


# Define the Menu
echo "Select the configuration for this Mac:"
echo "1) Personal (Full setup + Video tools)"
echo "2) Video Production (Work focused)"
echo "3) Family (Basic + Restrictions)"
echo "4) Quit"
echo ""

while true; do
    read -p "Enter choice [1-4]: " choice
    
    case $choice in
        1|2|3|4)
            break
            ;;
        *)
            echo "❌ Invalid option. Please enter 1-4."
            ;;
    esac
done

case $choice in
    1)
        TAGS="always,personal,video"
        DESC="Personal Machine"
        ;;
    2)
        TAGS="always,video"
        DESC="Video Production Machine"
        ;;
    3)
        TAGS="always,family"
        DESC="Family Machine"
        ;;
    4)
        echo "Exiting..."
        exit 0
        ;;
esac

echo ""
echo "🚀 Ready to provision: $DESC"
echo "   Tags: $TAGS"
read -p "Continue? [y/N]: " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi




# Dynamically determine the Homebrew prefix and Python path
if [[ $(uname -m) == "arm64" ]]; then
    BREW_PATH="/opt/homebrew/bin/python3"
else
    BREW_PATH="/usr/local/bin/python3"
fi

echo ""
echo "🚀 Starting provisioning for: $DESC"
echo "----------------------------------------------------"

# Run Ansible with the dynamic interpreter path
if ! ansible-playbook site.yml \
    -i inventory.ini \
    -K \
    -e "ansible_python_interpreter=$BREW_PATH" \
    --tags "$TAGS" \
    -v; then
    echo ""
    echo "❌ Provisioning failed. Check errors above."
    exit 1
fi


echo ""
echo "===================================================="
echo "✅ Provisioning Complete for: $DESC"
echo "===================================================="
echo ""
echo "💡 Next steps:"
echo "   - Restart your Mac if system preferences were changed"
echo "   - Check $REPO_ROOT for logs if issues occurred"

# Optional: Self-Destruct for Family Macs
if [ "$choice" == "3" ]; then
    echo ""
    read -p "🧹 Delete setup files? [y/N]: " cleanup
    if [[ "$cleanup" =~ ^[Yy]$ ]]; then
        echo "Cleaning up $REPO_ROOT..."
        rm -rf "$REPO_ROOT"
        echo "✅ Setup files removed."
    fi
fi