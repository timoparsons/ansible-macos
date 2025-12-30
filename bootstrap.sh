#!/bin/bash
set -e

REPO_DEST="$HOME/mac-setup"
REPO_URL="https://github.com/timoparsons/ansible-macos.git"

# Ensure Xcode Command Line Tools are installed
if ! xcode-select -p &>/dev/null; then
    echo "⏳ Waiting for Xcode Command Line Tools installation..."
    for i in {1..60}; do
        if xcode-select -p &>/dev/null; then
            break
        fi
        if [ $i -eq 60 ]; then
            echo "❌ Xcode installation timed out. Please complete manually."
            exit 1
        fi
        sleep 5
    done
fi

# Install Homebrew (only if missing)
if ! command -v brew &>/dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Ensure Homebrew is in PATH for the current session
if [[ $(uname -m) == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Install Git & GitHub CLI
echo "🛠️ Ensuring Git and GitHub CLI are present..."
brew install git gh

# Authenticate (only if not already logged in)
if gh auth status &>/dev/null; then
    echo "✅ Already logged in to GitHub."
else
    echo "🔑 Please login to GitHub to download the provisioning scripts:"
    gh auth login --scopes "repo" --web
    
    # Verify authentication worked
    if ! gh auth status &>/dev/null; then
        echo "❌ GitHub authentication failed. Exiting."
        exit 1
    fi
fi

# Clone or update repository
if [ ! -d "$REPO_DEST" ]; then
    echo "📥 Cloning repository..."
    if ! gh repo clone "$REPO_URL" "$REPO_DEST"; then
        echo "❌ Failed to clone repository. Exiting."
        exit 1
    fi
else
    echo "📄 Repository exists, pulling latest changes..."
    if ! (cd "$REPO_DEST" && git pull); then
        echo "⚠️  Failed to pull updates, continuing with existing version..."
    fi
fi

# Configure passwordless sudo for automation
echo "🔐 Configuring passwordless sudo..."
if ! sudo -n true 2>/dev/null; then
    echo "Standard sudo password required to configure automation permissions:"
fi

SUDOERS_FILE="/etc/sudoers.d/$USER"
if [ ! -f "$SUDOERS_FILE" ]; then
    echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    echo "✅ Passwordless sudo configured."
else
    echo "✅ Passwordless sudo already configured."
fi

# Hand off to setup script
echo ""
echo "✅ Bootstrap complete! Starting setup..."
echo ""

chmod +x "$REPO_DEST/scripts/setup.sh"
"$REPO_DEST/scripts/setup.sh"