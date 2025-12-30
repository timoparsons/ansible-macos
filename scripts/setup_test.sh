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

echo "🔧 Ensuring Python3 is accessible via /usr/bin/env..."

# Determine the correct Homebrew Python path
if [[ $(uname -m) == "arm64" ]]; then
    BREW_PYTHON="/opt/homebrew/bin/python3"
else
    BREW_PYTHON="/usr/local/bin/python3"
fi

# Verify Homebrew Python exists
if [ ! -f "$BREW_PYTHON" ]; then
    echo "❌ Homebrew Python not found at $BREW_PYTHON"
    exit 1
fi

# Test if /usr/bin/env can find python3
if ! /usr/bin/env python3 --version &>/dev/null; then
    echo "⚠️  Creating symlink so /usr/bin/env can find python3..."
    
    # Ensure /usr/local/bin exists
    sudo mkdir -p /usr/local/bin
    
    # Create or update the symlink
    sudo ln -sf "$BREW_PYTHON" /usr/local/bin/python3
    
    # Verify it worked
    if /usr/bin/env python3 --version &>/dev/null; then
        echo "✅ Symlink created successfully"
    else
        echo "❌ Symlink creation failed"
        exit 1
    fi
else
    echo "✅ Python3 is already accessible via /usr/bin/env"
fi


# Clear screen for a clean start
#clear

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


TAGS="video"
DESC="Video Production Machine TEST"


echo ""
echo "🚀 Ready to provision: $DESC"
echo "   Tags: $TAGS"
read -p "Continue? [y/N]: " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi


echo ""
echo "🚀 Starting provisioning for: $DESC"
echo "----------------------------------------------------"

# Run Ansible with the dynamic interpreter path
if ! ansible-playbook site.yml \
    -i inventory.ini \
    -K \
    --tags "never,video" \
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

