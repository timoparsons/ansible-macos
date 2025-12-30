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


# Install Homebrew (Only if missing)
if ! command -v brew &>/dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi


# Ensure Homebrew and its Python are in the PATH for the current session
if [[ $(uname -m) == "arm64" ]]; then
    # Silicon Path
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    # Intel Path
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Explicitly export the path so Ansible sub-processes inherit it
export PATH="$(brew --prefix)/bin:$(brew --prefix)/sbin:$PATH"


# Install Git & GitHub CLI
echo "🛠️ Ensuring Git and GitHub CLI are present..."
brew install git gh


# Authenticate (Only if NOT already logged in)
if gh auth status &>/dev/null; then
    echo "✅ Already logged in to GitHub."
else
    echo "🔐 Please login to GitHub to download the provisioning scripts:"
    gh auth login --scopes "repo" --web
fi

# After gh auth login, verify it worked
if ! gh auth status &>/dev/null; then
    echo "❌ GitHub authentication failed. Exiting."
    exit 1
fi


# Define Destination and Clone
if [ ! -d "$REPO_DEST" ]; then
    echo "📥 Cloning repository..."
    if ! gh repo clone "$REPO_URL" "$REPO_DEST"; then
        echo "❌ Failed to clone repository. Exiting."
        exit 1
    fi
else
    echo "🔄 Repository exists, pulling latest changes..."
    if ! (cd "$REPO_DEST" && git pull); then
        echo "⚠️  Failed to pull updates, but continuing with existing version..."
    fi
fi


# Logout of Github (Optional - you can leave this out for Personal Macs if you prefer)
#echo "🔓 Logging out of GitHub CLI to stay clean..."
#gh auth logout --yes


# Ensure passwordless sudo for the current user to prevent Cask installation failures
echo "🔐 Configuring passwordless sudo..."
if ! sudo -n true 2>/dev/null; then
    echo "Standard sudo password required to configure automation permissions:"
fi


# Create a sudoers file specifically for this user
SUDOERS_FILE="/etc/sudoers.d/$USER"
if [ ! -f "$SUDOERS_FILE" ]; then
    echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    echo "✅ Passwordless sudo configured."
else
    echo "✅ Passwordless sudo already configured."
fi

# Hand off to the Private Orchestrator
echo ""
echo "✅ Bootstrap complete! Starting setup..."
echo ""

chmod +x "$REPO_DEST/scripts/setup.sh"
"$REPO_DEST/scripts/setup.sh" 