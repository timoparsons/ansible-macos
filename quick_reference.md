# Quick Reference Guide

Common commands and examples for macOS Ansible provisioning with compressed backups.

## Table of Contents

- [Common Commands](#common-commands)
- [Provisioning](#provisioning)
- [Backup Commands](#backup-commands)
- [Restore Commands](#restore-commands)
- [Checking Backup Contents](#checking-backup-contents)
- [Tag Reference](#tag-reference)
- [Selective Operations](#selective-operations)
- [App Management](#app-management)
- [System Configuration](#system-configuration)
- [Utilities](#utilities)
- [Variables](#variables)
- [Common Workflows](#common-workflows)


---

## Common Commands

### Backup

```bash
# Backup single app
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit studio -e "apps_list=resolve"

# List all files in a backup
zstd -d -c /Volumes/backup_proxmox/macos/apps/resolve/resolve-studio-20260127.tar.zst | tar -tf -

# View manifest with jq (pretty-printed)
zstd -d -c /Volumes/backup_proxmox/macos/apps/resolve/resolve-studio-20260127.tar.zst | tar -xOf - manifest.json | jq .

```

### Restore

```bash
# SSH into laptop and update
ssh laptop
cd mac-setup
git fetch --all
git reset --hard origin/main

# Install app
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit laptop \
  -e "apps_list=handbrake"

# Restore app settings
ansible-playbook playbooks/selective/restore-apps-selective.yml \
-i inventory.ini --limit studio \
-e "apps_list=resolve" -K
```




---

## Provisioning

### Full Provision

```bash
# Studio machine - full install + restore
ansible-playbook site.yml -i inventory.ini --limit studio -K

# Laptop machine
ansible-playbook site.yml -i inventory.ini --limit laptop -K

# Editor machine
ansible-playbook site.yml -i inventory.ini --limit editor -K

# Family machine
ansible-playbook site.yml -i inventory.ini --limit family -K
```

### Skip Automatic Restore

```bash
# Install apps and configure system, but don't restore settings
ansible-playbook site.yml -i inventory.ini --limit studio -K --skip-tags restore

# OR use variable
ansible-playbook site.yml -i inventory.ini --limit studio -K -e "restore_app_settings=false"
```

### Apps Only

```bash
# Install all apps, skip everything else
ansible-playbook site.yml -i inventory.ini --limit studio --tags apps

# Just Homebrew apps (fastest)
ansible-playbook site.yml -i inventory.ini --limit studio --tags brew

# Just casks (GUI apps)
ansible-playbook site.yml -i inventory.ini --limit studio --tags cask

# Skip slow DMG installations
ansible-playbook site.yml -i inventory.ini --limit studio --skip-tags dmg
```

### Configuration Only

```bash
# Apply all configuration (SSH, dotfiles, macOS defaults, dock, login items, restore)
ansible-playbook site.yml -i inventory.ini --limit studio --tags config

# Just macOS system preferences
ansible-playbook site.yml -i inventory.ini --limit studio --tags macos_defaults

# Just Dock
ansible-playbook site.yml -i inventory.ini --limit studio --tags dock

# Just login items
ansible-playbook site.yml -i inventory.ini --limit studio --tags login_items
```

### Dry Run (Test Mode)

```bash
# See what would change without making changes
ansible-playbook site.yml -i inventory.ini --limit studio --check
```

---

## Backup Commands

### Backup Everything

```bash
# Full backup (SSH + apps + dotfiles)
ansible-playbook playbooks/backup-full.yml -i inventory.ini --limit studio

# Individual components
ansible-playbook playbooks/backup-ssh.yml -i inventory.ini --limit studio
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit studio
ansible-playbook playbooks/backup-dotfiles.yml -i inventory.ini --limit studio

# Export current login items to YAML
ansible-playbook playbooks/backup-login-items.yml -i inventory.ini --limit studio
```

**Note:** SSH backups only work on studio/laptop (they have private keys).

### Selective App Backup

```bash
# Backup specific apps only
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit studio \
  -e "apps_list=raycast,vscode,resolve"

# Backup just one app
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit studio \
  -e "apps_list=strongbox"

# Backup fonts
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit studio \
  -e "apps_list=user-fonts,adobe-fonts"
```

### Backup Output Format

All backups are compressed with zstd:

```
/Volumes/backup_proxmox/macos/
├── ssh/
│   └── ssh-studio-20260127.tar.zst         # ~90% compression
├── apps/
│   ├── raycast/
│   │   └── raycast-studio-20260127.tar.zst
│   └── user-fonts/
│       └── user-fonts-studio-20260127.tar.zst
└── dotfiles/
    └── dotfiles-studio-20260127.tar.zst
```

---

## Restore Commands

### Restore Everything

```bash
# SSH keys
ansible-playbook playbooks/restore-ssh.yml -i inventory.ini --limit studio

# All app settings (prompts for confirmation)
ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit studio

# Dotfiles
ansible-playbook playbooks/restore-dotfiles.yml -i inventory.ini --limit studio
```

### Auto-confirm (Skip Prompts)

```bash
# Restore apps without confirmation prompt
ansible-playbook playbooks/restore-apps.yml \
  -i inventory.ini --limit studio \
  -e "auto_confirm=true"
```

### Selective App Restore

```bash
# Restore specific apps only
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=raycast,vscode"

# Restore just one app
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=crossover"

# Restore fonts
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=user-fonts,adobe-fonts"
```

### Cross-Role Restore

```bash
# Restore laptop's SSH keys to studio
ansible-playbook playbooks/restore-ssh.yml -i inventory.ini --limit studio \
  -e "restore_from_machine=laptop"

# Restore studio's dotfiles to laptop
ansible-playbook playbooks/restore-dotfiles.yml -i inventory.ini --limit laptop \
  -e "restore_from_machine=studio"
```

### Restore During Provisioning

```bash
# Default: Apps + config + automatic restore for installed apps
ansible-playbook site.yml -i inventory.ini --limit studio -K

# Just restore app settings (after apps are already installed)
ansible-playbook site.yml -i inventory.ini --limit studio --tags restore
```

---

## Checking Backup Contents

### List Files in Backup

```bash
# List all files in a backup
zstd -d -c /Volumes/backup_proxmox/macos/apps/raycast/raycast-studio-20260127.tar.zst | tar -tf -

# Show first 20 files
zstd -d -c backup.tar.zst | tar -tf - | head -20

# Show directory structure sorted
zstd -d -c backup.tar.zst | tar -tf - | sort

# Show only directories
zstd -d -c backup.tar.zst | tar -tf - | grep '/$'
```

### View Manifest

Every backup includes a `manifest.json` with metadata:

```bash
# View manifest with jq (pretty-printed)
zstd -d -c /Volumes/backup_proxmox/macos/apps/raycast/raycast-studio-20260127.tar.zst | tar -xOf - manifest.json | jq .

# View manifest without jq
zstd -d -c backup.tar.zst | tar -xOf - manifest.json

# Extract just the manifest to current directory
zstd -d -c backup.tar.zst | tar -xf - manifest.json

# Check what app a backup is for
zstd -d -c backup.tar.zst | tar -xOf - manifest.json | jq -r '.app_name'

# Check backup date
zstd -d -c backup.tar.zst | tar -xOf - manifest.json | jq -r '.backup_date'

# See all paths in manifest
zstd -d -c backup.tar.zst | tar -xOf - manifest.json | jq -r '.paths[].src'
```

### Check Compression Ratio

```bash
# Compare original vs compressed size
BACKUP="/Volumes/backup_proxmox/macos/apps/raycast/raycast-studio-20260127.tar.zst"
COMPRESSED=$(ls -lh "$BACKUP" | awk '{print $5}')
ORIGINAL=$(zstd -d -c "$BACKUP" | wc -c | awk '{printf "%.2f MB", $1/1024/1024}')
echo "Compressed: $COMPRESSED"
echo "Original: $ORIGINAL"
```

### Extract Specific File from Backup

```bash
# Extract a specific file without extracting the entire archive
zstd -d -c backup.tar.zst | tar -xf - path/to/specific/file

# Example: Extract just the preferences file
zstd -d -c raycast-studio-20260127.tar.zst | tar -xf - raycast/preferences/com.raycast.macos.plist
```

### Verify Backup Integrity

```bash
# Test archive integrity
zstd -t backup.tar.zst && echo "✅ Archive OK" || echo "❌ Archive corrupted"

# Test decompression and tar structure
zstd -d -c backup.tar.zst | tar -tf - > /dev/null && echo "✅ Valid tar.zst" || echo "❌ Invalid"
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
| `restore` | App settings restoration | `--tags restore` |

### Role Tags

| Tag | Description | Example |
|-----|-------------|---------|
| `studio` | Studio role tasks | `--tags studio` |
| `laptop` | Laptop role tasks | `--tags laptop` |
| `editor` | Editor role tasks | `--tags editor` |
| `family` | Family role tasks | `--tags family` |

### List All Available Tags

```bash
ansible-playbook site.yml -i inventory.ini --limit studio --list-tags
```

---

## Selective Operations

### Install Specific Apps

Instead of installing all apps, install just specific ones:

```bash
# Install specific apps by name
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=spotify,typeface"

# Install single app
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit laptop \
  -e "apps_list=handbrake"

# Install multiple apps from different sources (auto-detected)
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=dockutil,raycast,affinity"
```

The playbook automatically detects which installation method to use (formula, cask, MAS, or DMG).

### Install + Restore Workflow

```bash
# One-liner to install and restore a new app
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit studio -e "apps_list=typeface" && \
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit studio -e "apps_list=typeface"
```

### Combine Tags

```bash
# Install apps + restore settings, skip system config
ansible-playbook site.yml -i inventory.ini --limit studio --tags apps,restore

# macOS defaults + Dock + login items only
ansible-playbook site.yml -i inventory.ini --limit studio --tags macos_defaults,dock,login_items

# Everything except restore
ansible-playbook site.yml -i inventory.ini --limit studio --skip-tags restore
```

---

## App Management

### Check Which Apps Are Configured

```bash
# List all apps with backup definitions
grep -E "^  [a-z-]+:" vars/app_backups.yml

# List apps backed up for studio machine
grep -A50 "studio_apps_to_backup:" vars/app_backups.yml

# List apps backed up for laptop machine
grep -A50 "laptop_apps_to_backup:" vars/app_backups.yml

# Check which apps are installed on studio
grep -A50 "studio_cask_apps:" group_vars/studio.yml
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

## System Configuration

### macOS Defaults

```bash
# Apply all macOS defaults
ansible-playbook site.yml -i inventory.ini --limit studio --tags macos_defaults

# Dry run (see what would change)
ansible-playbook site.yml -i inventory.ini --limit studio --tags macos_defaults --check

# Apply and show changes
ansible-playbook site.yml -i inventory.ini --limit studio --tags macos_defaults -v
```

### Dock Configuration

```bash
# Configure Dock
ansible-playbook site.yml -i inventory.ini --limit studio --tags dock

# Skip Dock configuration during provisioning
ansible-playbook site.yml -i inventory.ini --limit studio -K -e "configure_dock=false"
```

### Login Items

```bash
# Configure login items
ansible-playbook site.yml -i inventory.ini --limit studio --tags login_items

# Export current login items to YAML file
ansible-playbook playbooks/backup-login-items.yml -i inventory.ini --limit studio

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
ls -la /Volumes/backup_proxmox/macos/ssh/

# Check app backups
ls -la /Volumes/backup_proxmox/macos/apps/

# Check dotfiles backup
ls -la /Volumes/backup_proxmox/macos/dotfiles/

# Find all backups for today
find /Volumes/backup_proxmox/macos -name "*$(date +%Y%m%d).tar.zst"

# Find all backups for studio role
find /Volumes/backup_proxmox/macos -name "*-studio-*.tar.zst"
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

### Check Disk Space

```bash
# Check space on network volume
df -h /Volumes/backup_proxmox

# Check space in /tmp (used during backup compression)
df -h /tmp

# Check total size of all backups
du -sh /Volumes/backup_proxmox/macos/*
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
| `auto_confirm` | `false` | Skip confirmation prompts |
| `restore_from_machine` | `{current}` | Which machine's backup to restore from |
| `apps_list` | `[]` | Specific apps for selective operations |

### Using Variables

```bash
# Disable automatic restore
ansible-playbook site.yml -i inventory.ini --limit studio -K \
  -e "restore_app_settings=false"

# Auto-confirm restore without prompts
ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit studio \
  -e "auto_confirm=true"

# Skip dock configuration
ansible-playbook site.yml -i inventory.ini --limit studio -K \
  -e "configure_dock=false"

# Restore laptop's backup to studio
ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit studio \
  -e "restore_from_machine=laptop"

# Selective app backup
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit studio \
  -e "apps_list=raycast,vscode,resolve"
```

---

## Common Workflows

### New Machine Setup

```bash
# 1. Run bootstrap (installs prerequisites)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/timoparsons/ansible-macos/main/scripts/bootstrap.sh)"

# 2. Mount network volume (via Finder: Cmd+K)
# smb://your-server/backup_proxmox

# 3. Run full provision (installs apps + configures + restores)
cd ~/mac-setup
./scripts/setup.sh
# OR
ansible-playbook site.yml -i inventory.ini --limit studio -K
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

### Before Wiping Machine

```bash
# 1. Deactivate seat-limited licenses (see docs/deactivation.md)

# 2. Backup everything
ansible-playbook playbooks/backup-full.yml -i inventory.ini --limit studio

# 3. Verify backups exist
ls -la /Volumes/backup_proxmox/macos/ssh/
ls -la /Volumes/backup_proxmox/macos/apps/
ls -la /Volumes/backup_proxmox/macos/dotfiles/

# 4. Check a few backup contents
zstd -d -c /Volumes/backup_proxmox/macos/apps/raycast/raycast-studio-*.tar.zst | tar -tf - | head -10
```

### Testing Changes

```bash
# Dry run (see what would change)
ansible-playbook site.yml -i inventory.ini --limit studio --check

# Install only fast apps for testing
ansible-playbook site.yml -i inventory.ini --limit studio --tags brew

# Test specific role
ansible-playbook site.yml -i inventory.ini --limit studio --tags studio --check

# Verbose output
ansible-playbook site.yml -i inventory.ini --limit studio -v
```

### Updating App Backups

```bash
# 1. Make changes in the app

# 2. Backup updated settings
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit studio

# OR backup just that app
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit studio \
  -e "apps_list=appname"

# 3. Verify backup was created
ls -lh /Volumes/backup_proxmox/macos/apps/appname/

# 4. Check what was backed up
zstd -d -c /Volumes/backup_proxmox/macos/apps/appname/appname-studio-*.tar.zst | tar -tf - | head -20
```

### Migrating Between Machines

```bash
# Scenario: Copying studio setup to new laptop

# 1. On studio: Backup everything
ansible-playbook playbooks/backup-full.yml -i inventory.ini --limit studio

# 2. On laptop: Run bootstrap
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/...bootstrap.sh)"

# 3. On laptop: Mount network volume

# 4. On laptop: Provision with studio's backups
cd ~/mac-setup

# Install apps (from laptop's config)
ansible-playbook site.yml -i inventory.ini --limit laptop --tags apps

# Restore settings from studio's backups
ansible-playbook playbooks/restore-ssh.yml -i inventory.ini --limit laptop \
  -e "restore_from_machine=studio"

ansible-playbook playbooks/restore-dotfiles.yml -i inventory.ini --limit laptop \
  -e "restore_from_machine=studio"

ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit laptop \
  -e "restore_from_machine=studio"
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
ansible-playbook site.yml -i inventory.ini --limit studio -v

# Level 2: More details
ansible-playbook site.yml -i inventory.ini --limit studio -vv

# Level 3: Debug everything
ansible-playbook site.yml -i inventory.ini --limit studio -vvv
```

### Check Specific Task

```bash
# Run only one role
ansible-playbook site.yml -i inventory.ini --limit studio --tags studio

# Run only specific tasks
ansible-playbook site.yml -i inventory.ini --limit studio --tags macos_defaults --check

# See task names
ansible-playbook site.yml -i inventory.ini --limit studio --list-tasks
```

### Re-run Failed Tasks

```bash
# If provisioning failed, re-run from where it stopped
ansible-playbook site.yml -i inventory.ini --limit studio -K --start-at-task="Task Name"

# Or just re-run the whole thing (it's idempotent)
ansible-playbook site.yml -i inventory.ini --limit studio -K
```

### Backup Troubleshooting

```bash
# Check if zstd is installed
which zstd || brew install zstd

# Test backup integrity
zstd -t /Volumes/backup_proxmox/macos/apps/raycast/raycast-studio-20260127.tar.zst

# Check backup file permissions
ls -l /Volumes/backup_proxmox/macos/apps/raycast/

# View backup creation date
stat /Volumes/backup_proxmox/macos/apps/raycast/raycast-studio-20260127.tar.zst

# Check if manifest exists in backup
zstd -d -c backup.tar.zst | tar -tf - | grep manifest.json
```

---

## Quick Command Summary

```bash
# PROVISIONING
ansible-playbook site.yml -i inventory.ini --limit studio -K              # Full provision
ansible-playbook site.yml -i inventory.ini --limit studio --tags apps     # Apps only
ansible-playbook site.yml -i inventory.ini --limit studio --tags config   # Config only
ansible-playbook site.yml -i inventory.ini --limit studio --skip-tags restore  # Skip restore

# BACKUP (compressed tar.zst format)
ansible-playbook playbooks/backup-full.yml -i inventory.ini --limit studio
ansible-playbook playbooks/backup-ssh.yml -i inventory.ini --limit studio
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit studio
ansible-playbook playbooks/backup-dotfiles.yml -i inventory.ini --limit studio

# RESTORE (automatic decompression)
ansible-playbook playbooks/restore-ssh.yml -i inventory.ini --limit studio
ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit studio
ansible-playbook playbooks/restore-dotfiles.yml -i inventory.ini --limit studio

# SELECTIVE
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit studio -e "apps_list=app1,app2"
ansible-playbook playbooks/selective/restore-apps-selective.yml -i inventory.ini --limit studio -e "apps_list=app1,app2"
ansible-playbook playbooks/selective/install-app-selective.yml -i inventory.ini --limit studio -e "apps_list=app1,app2"

# CHECK BACKUP CONTENTS
zstd -d -c backup.tar.zst | tar -tf - | head -20                         # List files
zstd -d -c backup.tar.zst | tar -xOf - manifest.json | jq .              # View manifest
zstd -t backup.tar.zst && echo "✅ OK" || echo "❌ Corrupted"            # Test integrity

# UTILITIES
./scripts/mac-software-audit.sh                    # Audit installed apps
./scripts/discover-app-files.sh "App Name"         # Find app settings
./scripts/manage-login-items.sh list               # List login items
ansible-playbook site.yml -i inventory.ini --limit studio --list-tags    # List tags
ansible-playbook site.yml -i inventory.ini --limit studio --check        # Dry run
```