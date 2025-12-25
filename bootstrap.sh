#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "----------------------------------------------------------"
echo "🚀 Starting macOS Provisioning Bootstrapper"
echo "----------------------------------------------------------"

# 1. Install Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
    echo "📦 Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "⚠️  WAIT: A popup has appeared. Please click 'Install' and wait for it to finish."
    read -p "Press [Enter] once the installation is complete to continue..."
fi

# 2. Install Homebrew
if ! command -v brew &>/dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Set path for the current session based on architecture
    if [[ $(uname -m) == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# 3. Install Requirements (Ansible and GitHub CLI)
echo "🛠️  Installing Ansible and GitHub CLI..."
brew install ansible gh

# 4. Authenticate with GitHub
# This will trigger the device-code flow
echo "🔐 Authenticating with GitHub to access your private Ansible repo..."
gh auth login --hostname github.com --scopes "repo,read:org" --web

# 5. Run Ansible Pull
# Replace the URL with your actual private repo URL
REPO_URL="https://github.com/YOUR_USERNAME/YOUR_PRIVATE_REPO.git"

echo "📥 Running ansible-pull from $REPO_URL..."
# -U: URL of the repository
# -C: Checkout the specific branch (default is main)
# -i: Use your inventory file inside the repo
# -K: Ask for become (sudo) password for system changes
# --ask-vault-pass: Only add this if you use Ansible Vault for secrets
ansible-pull -U "$REPO_URL" \
             -i inventory.ini \
             -K \
             site.yml

# 6. Optional: Cleanup GitHub Session
# Uncomment the line below if you don't want your GitHub account left logged in (good for family Macs)
# gh auth logout -y

echo "----------------------------------------------------------"
echo "✅ Bootstrap phase complete. Ansible is now configuring your Mac!"
echo "----------------------------------------------------------"