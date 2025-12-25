#!/bin/bash
set -e

REPO_DEST="$HOME/mac-setup"
REPO_URL="https://github.com/timoparsons/ansible-macos.git"

# 1. Install Homebrew (Only if missing)
if ! command -v brew &>/dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Ensure brew is in the current shell session's PATH
[[ $(uname -m) == "arm64" ]] && eval "$(/opt/homebrew/bin/brew shellenv)" || eval "$(/usr/local/bin/brew shellenv)"

# 2. Install Git & GitHub CLI (Brew handles the "is it already installed" check internally)
echo "🛠️ Ensuring Git and GitHub CLI are present..."
brew install git gh

# 3. Authenticate & Clone
echo "🔐 Please login to GitHub to download the provisioning scripts:"
gh auth login --scopes "repo" --web

if [ ! -d "$REPO_DEST" ]; then
    echo "📥 Cloning repository..."
    gh repo clone "$REPO_URL" "$REPO_DEST"
else
    echo "🔄 Repository exists, pulling latest changes..."
    cd "$REPO_DEST" && git pull
fi

# Logout of Github immediately after cloning
gh auth logout -y

# 4. Hand off to the Private Orchestrator
# Use the full path to ensure the script is found
chmod +x "$REPO_DEST/scripts/setup.sh"
"$REPO_DEST/scripts/setup.sh"