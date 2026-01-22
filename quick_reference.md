# Quick Reference Guide

Common commands and examples for macOS Ansible provisioning.

## Table of Contents

- [Provisioning](#provisioning)
- [Backup Commands](#backup-commands)
- [Restore Commands](#restore-commands)
- [Tag Reference](#tag-reference)
- [Selective Operations](#selective-operations)
- [App Management](#app-management)
- [System Configuration](#system-configuration)
- [Utilities](#utilities)
- [Variables](#variables)

---

## Provisioning

### Full Provision

```bash
# Personal machine - full install + restore
ansible-playbook site.yml -i inventory.ini --limit personal -K

# Video production machine
ansible-playbook site.yml -i inventory.ini --limit video -K

# Family machine
ansible-playbook site.yml -i inventory.ini --limit family -K
```

### Skip Automatic Restore

```bash
# Install apps and configure system, but don't restore settings
ansible-playbook site.yml -i inventory.ini --limit personal -K --skip-tags restore

# OR use variable
ansible-playbook site.yml -i inventory.ini --limit personal -K -e "restore_app_settings=false"
```

### Apps Only

```bash
# Install all apps, skip everything else
ansible-playbook site.yml -i inventory.ini --limit personal --tags apps

# Just Homebrew apps (fastest)
ansible-playbook site.yml -i inventory.ini --limit personal --tags brew

# Just casks (GUI apps)
ansible-playbook site.yml -i inventory.ini --limit personal --tags cask

# Skip slow DMG installations
ansible-playbook site.yml -i inventory.ini --limit personal --skip-tags dmg
```

### Configuration Only

```bash
# Apply all configuration (SSH, dotfiles, macOS defaults, dock, login items, restore)
ansible-playbook site.yml -i inventory.ini --limit personal --tags config

# Just macOS system preferences
ansible-playbook site.yml -i inventory.ini --limit personal --tags macos_defaults

# Just Dock
ansible-playbook site.yml -i inventory.ini --limit personal --tags dock

# Just login items
ansible-playbook site.yml -i inventory.ini --limit personal --tags login_items
```

### Dry Run (Test Mode)

```bash
# See what would change without making changes
ansible-playbook site.yml -i inventory.ini --limit personal --check
```

---

## Backup Commands

### Backup Everything

```bash
# SSH keys (personal machine only)
ansible-playbook playbooks/backup-ssh.yml -i inventory.ini --limit personal

# All app settings
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit personal

# Dotfiles
ansible-playbook playbooks/backup-dotfiles.yml -i inventory.ini --limit personal

# Fonts (WARNING: Replaces entire backup)
ansible-playbook playbooks/backup-fonts.yml -i inventory.ini --limit personal

# Export current login items to YAML
ansible-playbook playbooks/backup-login-items.yml -i inventory.ini --limit personal
```

### Selective App Backup

```bash
# Backup specific apps only
ansible-playbook playbooks/selective/backup-apps-selective.yml \
  -i inventory.ini --limit personal \
  -e "apps_list=raycast,vscode,davinci-resolve"

# Backup just one app
ansible-playbook playbooks/selective/backup-apps-selective.yml \
  -i inventory.ini --limit personal \
  -e "apps_list=strongbox"
```

### Timestamped Backups

```bash
# Create timestamped backup alongside current
ansible-playbook playbooks/backup-apps.yml \
  -i inventory.ini --limit personal \
  -e "backup_create_timestamped=true"
```

---

## Restore Commands

### Restore Everything

```bash
# SSH keys
ansible-playbook playbooks/restore-ssh.yml -i inventory.ini --limit personal

# All app settings (prompts for confirmation)
ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit personal

# Dotfiles
ansible-playbook playbooks/restore-dotfiles.yml -i inventory.ini --limit personal

# Fonts (WARNING: Replaces all fonts in ~/Library/Fonts)
ansible-playbook playbooks/restore-fonts.yml -i inventory.ini --limit personal
```

### Auto-confirm (Skip Prompts)

```bash
# Restore apps without confirmation prompt
ansible-playbook playbooks/restore-apps.yml \
  -i inventory.ini --limit personal \
  -e "auto_confirm=true"
```

### Selective App Restore

```bash
# Restore specific apps only
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit personal \
  -e "apps_list=raycast,vscode"

# Restore just one app
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit personal \
  -e "apps_list=crossover"
```

### Restore During Provisioning

```bash
# Default: Apps + config + automatic restore for installed apps
ansible-playbook site.yml -i inventory.ini --limit personal -K

# Just restore app settings (after apps are already installed)
ansible-playbook site.yml -i inventory.ini --limit personal --tags restore
```

---

## Tag Reference

### Installation Tags

| Tag | Description | Example |
|-----|-------------|---------|
| `apps` | All apps (brew + mas + dmg) | `--tags apps` |
| `brew` | All Homebrew (formulae + casks) | `--tags brew` |
| `formula` | CLI tools only | `--tags formula` |
| `cask` | Homebrew GUI apps only | `--tags cask` |
| `mas` | Mac App Store apps only | `--tags mas` |
| `dmg` | DMG/PKG installers only | `--tags dmg` |

### Configuration Tags

| Tag | Description | Example |
|-----|-------------|---------|
| `config` | All configuration | `--tags config` |
| `ssh` | SSH keys only | `--tags ssh` |
| `dotfiles` | Dotfiles only | `--tags dotfiles` |
| `macos_defaults` | macOS system preferences | `--tags macos_defaults` |
| `dock` | Dock configuration | `--tags dock` |
| `login_items` | Login items | `--tags login_items` |
| `fonts` | Font restoration | `--tags fonts` |
| `restore` | App settings restoration | `--tags restore` |

### Role Tags

| Tag | Description | Example |
|-----|-------------|---------|
| `personal` | Personal role tasks | `--tags personal` |
| `video` | Video role tasks | `--tags video` |
| `family` | Family role tasks | `--tags family` |

### List All Available Tags

```bash
ansible-playbook site.yml -i inventory.ini --limit personal --list-tags
```

---

## Selective Operations

### Install Specific App Types

```bash
# Only CLI tools (fast)
ansible-playbook site.yml -i inventory.ini --limit personal --tags formula

# Only GUI apps from Homebrew
ansible-playbook site.yml -i inventory.ini --limit personal --tags cask

# Only Mac App Store apps
ansible-playbook site.yml -i inventory.ini --limit personal --tags mas

# Everything except DMG installers (faster testing)
ansible-playbook site.yml -i inventory.ini --limit personal --skip-tags dmg
```

### Configure Specific Aspects

```bash
# Only apply macOS defaults, skip everything else
ansible-playbook site.yml -i inventory.ini --limit personal --tags macos_defaults

# Only configure Dock
ansible-playbook site.yml -i inventory.ini --limit personal --tags dock

# Only set up SSH keys
ansible-playbook site.yml -i inventory.ini --limit personal --tags ssh

# Only restore fonts
ansible-playbook site.yml -i inventory.ini --limit personal --tags fonts
```

### Combine Tags

```bash
# Install apps + restore settings, skip system config
ansible-playbook site.yml -i inventory.ini --limit personal --tags apps,restore

# macOS defaults + Dock + login items only
ansible-playbook site.yml -i inventory.ini --limit personal --tags macos_defaults,dock,login_items

# Everything except restore
ansible-playbook site.yml -i inventory.ini --limit personal --skip-tags restore
```

---

## App Management

### Check Which Apps Are Configured

```bash
# List all apps with backup definitions
grep -E "^  [a-z-]+:" vars/app_backups.yml

# List apps backed up for personal machine
grep -A50 "personal_apps_to_backup:" vars/app_backups.yml

# List apps backed up for video machine
grep -A50 "video_apps_to_backup:" vars/app_backups.yml
```

### Discover App Settings Locations

```bash
# Find where an app stores its settings
./scripts/discover-app-files.sh "App Name"

# Examples
./scripts/discover-app-files.sh "Raycast"
./scripts/discover-app-files.sh "Visual Studio Code"
./scripts/discover-app-files.sh "DaVinci Resolve"

# Creates: app-discovery-App-Name.txt
```

### Audit Installed Apps

```bash
# Find apps not managed by Homebrew
./scripts/mac-software-audit.sh

# Creates: mac_software_audit.txt
# Shows:
#   - Homebrew formulas (CLI tools)
#   - Homebrew casks (GUI apps)
#   - Apps that could be converted to casks
```

---

## Selective App Installation

### Install Specific Apps Only

Instead of installing all apps for a role, you can install just specific apps:

```bash
# Install specific apps by name
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=spotify,typeface"

# Install single app
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit laptop \
  -e "apps_list=handbrake"

# Install multiple apps from different sources
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=dockutil,raycast,affinity"
```

### How It Works

The playbook automatically:
- Detects which installation method each app uses (brew formula, cask, MAS, or DMG)
- Installs only the requested apps
- Shows which apps weren't found in your machine's configuration
- Suggests adding missing apps to `group_vars/{machine_type}.yml`

### Examples by App Type

```bash
# CLI tools (formulae)
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=tree,exiftool,starship"

# GUI apps (casks)
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=visual-studio-code,blender,iina"

# Mac App Store apps (use app name, not ID)
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=tailscale,strongbox-pro,typeface"

# DMG/PKG apps
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=crossover,offshoot"
```

### After Installation

Once apps are installed, restore their settings:

```bash
# Restore settings for newly installed apps
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=spotify,typeface"
```

---

## System Configuration

### macOS Defaults

```bash
# Apply all macOS defaults
ansible-playbook site.yml -i inventory.ini --limit personal --tags macos_defaults

# Dry run (see what would change)
ansible-playbook site.yml -i inventory.ini --limit personal --tags macos_defaults --check

# Apply and show changes
ansible-playbook site.yml -i inventory.ini --limit personal --tags macos_defaults -v
```

### Dock Configuration

```bash
# Configure Dock
ansible-playbook site.yml -i inventory.ini --limit personal --tags dock

# Skip Dock configuration during provisioning
ansible-playbook site.yml -i inventory.ini --limit personal -K -e "configure_dock=false"
```

### Login Items

```bash
# Configure login items
ansible-playbook site.yml -i inventory.ini --limit personal --tags login_items

# Export current login items to YAML file
ansible-playbook playbooks/backup-login-items.yml -i inventory.ini --limit personal

# Manually manage login items
./scripts/manage-login-items.sh list
./scripts/manage-login-items.sh add Raycast
./scripts/manage-login-items.sh add-hidden AutoMounter
./scripts/manage-login-items.sh remove Spotify
```

---

## Utilities

### Network Volume Check

```bash
# Verify network volumes are mounted
ls -la /Volumes/backup_proxmox/

# Mount via Finder if not mounted
# Cmd+K → smb://your-server/backup_proxmox
```

### Verify Backups Exist

```bash
# Check SSH backup
ls -la /Volumes/backup_proxmox/macos/ssh/personal/

# Check app backups
ls -la /Volumes/backup_proxmox/macos/apps/

# Check dotfiles backup
ls -la /Volumes/backup_proxmox/macos/dotfiles/personal/

# Check fonts backup
ls -la /Volumes/backup_proxmox/macos/fonts/
```

### Passwordless Sudo Check

```bash
# Verify passwordless sudo is configured
sudo -n true && echo "✅ Configured" || echo "❌ Not configured"

# If not configured, run bootstrap again
./scripts/bootstrap.sh
```

### Homebrew Path

```bash
# Apple Silicon
eval "$(/opt/homebrew/bin/brew shellenv)"

# Intel
eval "$(/usr/local/bin/brew shellenv)"
```

---

## Variables

### Common Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `restore_app_settings` | `true` | Auto-restore app settings during provisioning |
| `restore_fonts` | `true` | Auto-restore fonts during provisioning |
| `configure_dock` | `true` | Configure Dock during provisioning |
| `configure_login_items` | `true` | Configure login items during provisioning |
| `backup_create_timestamped` | `false` | Create timestamped backups |
| `auto_confirm` | `false` | Skip confirmation prompts |

### Using Variables

```bash
# Disable automatic restore
ansible-playbook site.yml -i inventory.ini --limit personal -K \
  -e "restore_app_settings=false"

# Create timestamped backup
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit personal \
  -e "backup_create_timestamped=true"

# Auto-confirm restore without prompts
ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit personal \
  -e "auto_confirm=true"

# Skip dock configuration
ansible-playbook site.yml -i inventory.ini --limit personal -K \
  -e "configure_dock=false"
```

---

## Common Workflows

### New Machine Setup

```bash
# 1. Run bootstrap (installs prerequisites)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/timoparsons/ansible-macos/main/scripts/bootstrap.sh)"

# 2. Mount network volume (via Finder: Cmd+K)

# 3. Run full provision (installs apps + configures + restores)
cd ~/mac-setup
./scripts/setup.sh
# OR
ansible-playbook site.yml -i inventory.ini --limit personal -K
```


### After Manual App Installation

```bash
# Method 1: Restore all installed apps during full provision
ansible-playbook site.yml -i inventory.ini --limit studio --tags restore

# Method 2: Restore specific apps only
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=newapp1,newapp2"

# Method 3: Install specific apps then restore their settings
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=newapp1,newapp2"

ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=newapp1,newapp2"
```

### Quick App Install + Restore

```bash
# One-liner to install and restore a new app
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit studio -e "apps_list=typeface" && \
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit studio -e "apps_list=typeface"
```

### Before Wiping Machine

```bash
# 1. Deactivate seat-limited licenses (see docs/deactivation.md)

# 2. Backup everything
ansible-playbook playbooks/backup-ssh.yml -i inventory.ini --limit personal
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit personal
ansible-playbook playbooks/backup-dotfiles.yml -i inventory.ini --limit personal
ansible-playbook playbooks/backup-fonts.yml -i inventory.ini --limit personal

# 3. Verify backups
ls -la /Volumes/backup_proxmox/macos/ssh/personal/
ls -la /Volumes/backup_proxmox/macos/apps/
```

### Testing Changes

```bash
# Dry run (see what would change)
ansible-playbook site.yml -i inventory.ini --limit personal --check

# Install only fast apps for testing
ansible-playbook site.yml -i inventory.ini --limit personal --tags brew

# Test specific role
ansible-playbook site.yml -i inventory.ini --limit personal --tags personal --check

# Verbose output
ansible-playbook site.yml -i inventory.ini --limit personal -v
```

### Updating App Backups

```bash
# 1. Make changes in the app

# 2. Backup updated settings
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit personal

# OR backup just that app
ansible-playbook playbooks/selective/backup-apps-selective.yml \
  -i inventory.ini --limit personal \
  -e "apps_list=appname"

# 3. Verify backup
ls -la /Volumes/backup_proxmox/macos/apps/
```

---

## Troubleshooting Commands

### Check Ansible Syntax

```bash
# Validate playbook syntax
ansible-playbook site.yml -i inventory.ini --syntax-check

# Validate specific playbook
ansible-playbook playbooks/restore-apps.yml -i inventory.ini --syntax-check
```

### Verbose Output

```bash
# Level 1: Basic info
ansible-playbook site.yml -i inventory.ini --limit personal -v

# Level 2: More details
ansible-playbook site.yml -i inventory.ini --limit personal -vv

# Level 3: Debug everything
ansible-playbook site.yml -i inventory.ini --limit personal -vvv
```

### Check Specific Task

```bash
# Run only one role
ansible-playbook site.yml -i inventory.ini --limit personal --tags personal

# Run only specific tasks
ansible-playbook site.yml -i inventory.ini --limit personal --tags macos_defaults --check

# See task names
ansible-playbook site.yml -i inventory.ini --limit personal --list-tasks
```

### Re-run Failed Tasks

```bash
# If provisioning failed, re-run from where it stopped
ansible-playbook site.yml -i inventory.ini --limit personal -K --start-at-task="Task Name"

# Or just re-run the whole thing (it's idempotent)
ansible-playbook site.yml -i inventory.ini --limit personal -K
```

---

## Quick Command Summary

```bash
# PROVISIONING
ansible-playbook site.yml -i inventory.ini --limit personal -K              # Full provision
ansible-playbook site.yml -i inventory.ini --limit personal --tags apps     # Apps only
ansible-playbook site.yml -i inventory.ini --limit personal --tags config   # Config only
ansible-playbook site.yml -i inventory.ini --limit personal --skip-tags restore  # Skip restore

# BACKUP
ansible-playbook playbooks/backup-ssh.yml -i inventory.ini --limit personal
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit personal
ansible-playbook playbooks/backup-dotfiles.yml -i inventory.ini --limit personal
ansible-playbook playbooks/backup-fonts.yml -i inventory.ini --limit personal

# RESTORE
ansible-playbook playbooks/restore-ssh.yml -i inventory.ini --limit personal
ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit personal
ansible-playbook playbooks/restore-dotfiles.yml -i inventory.ini --limit personal
ansible-playbook playbooks/restore-fonts.yml -i inventory.ini --limit personal

# SELECTIVE
ansible-playbook playbooks/selective/backup-apps-selective.yml -i inventory.ini --limit personal -e "apps_list=app1,app2"
ansible-playbook playbooks/selective/restore-apps-selective.yml -i inventory.ini --limit personal -e "apps_list=app1,app2"

# UTILITIES
./scripts/mac-software-audit.sh                    # Audit installed apps
./scripts/discover-app-files.sh "App Name"         # Find app settings
./scripts/manage-login-items.sh list               # List login items
ansible-playbook site.yml -i inventory.ini --limit personal --list-tags    # List tags
ansible-playbook site.yml -i inventory.ini --limit personal --check        # Dry run
```