# macOS Provisioning with Ansible

Automated macOS setup using Ansible for consistent machine provisioning across Studio, Laptop, Editor, and Family configurations. Includes application installation, system configuration, and automatic settings backup/restore with compression.

## Quick Start

### First-Time Setup

```bash
# Run bootstrap script (installs prerequisites and clones repo)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/timoparsons/ansible-macos/main/scripts/bootstrap.sh)"
```

The bootstrap script will:
1. Install Xcode Command Line Tools
2. Install Homebrew
3. Install Python 3 and Ansible
4. Install Git and GitHub CLI
5. Authenticate with GitHub
6. Clone the repository to `~/mac-setup`
7. Configure passwordless sudo

### Full Setup – Manual Run

```bash
cd ~/mac-setup
./scripts/setup.sh
```

Choose your machine type:
1. **Tim Laptop** - Full creative/development setup + portability
2. **Studio Edit Machine** - Primary workstation with everything
3. **Edit Machine** - Video production focused
4. **Family Machine** - Basic apps and restrictions

The provisioning will:
1. Install all applications (Homebrew, Mac App Store, DMG/PKG)
2. Configure macOS system preferences
3. Set up the Dock and login items
4. **Automatically restore app settings, fonts, SSH keys, and dotfiles** (from network backup)

⚠️ **Important:** 
- Mount network volume `/Volumes/backup_proxmox` before running
- Log out and back in after provisioning for keyboard shortcuts to take effect

### Using Ansible Directly

```bash
# Full provision (apps + config + restore settings)
ansible-playbook site.yml -i inventory.ini --limit studio -K

# Install apps only, skip configuration
ansible-playbook site.yml -i inventory.ini --limit studio --tags apps

# Install apps + restore settings, skip system config
ansible-playbook site.yml -i inventory.ini --limit studio --tags apps,restore

# Just restore app settings (useful after manual installs)
ansible-playbook site.yml -i inventory.ini --limit studio --tags restore

# Skip automatic restore during provisioning
ansible-playbook site.yml -i inventory.ini --limit studio -K --skip-tags restore
```

## Project Structure

```
ansible-macos/
├── scripts/
│   ├── bootstrap.sh                  # First-run setup
│   ├── setup.sh                      # Main provisioning orchestrator
│   ├── mac-software-audit.sh         # Audit existing apps
│   ├── discover-app-files.sh         # Find app settings locations
│   ├── manage-login-items.sh         # Manage login items manually
│   └── create-role.sh                # Scaffold new machine roles
├── roles/                            # Self-contained machine roles
│   ├── studio/                       # Studio machine
│   │   ├── tasks/
│   │   │   ├── main.yml              # Main orchestrator
│   │   │   └── macos_settings.yml    # Studio-specific overrides
│   │   └── handlers/
│   ├── laptop/                       # Laptop machine
│   ├── editor/                       # Editor machine
│   └── family/                       # Family machine
├── group_vars/                       # Machine configurations
│   ├── all.yml                       # Global variables
│   ├── studio.yml                    # Studio apps, dock, login items
│   ├── laptop.yml                    # Laptop apps, dock, login items
│   ├── editor.yml                    # Editor apps, dock, login items
│   └── family.yml                    # Family apps, dock, login items
├── playbooks/                        # Backup/restore playbooks
│   ├── backup-ssh.yml                # Backup SSH keys (compressed)
│   ├── backup-apps.yml               # Backup app settings (compressed)
│   ├── backup-dotfiles.yml           # Backup dotfiles (compressed)
│   ├── backup-login-items.yml        # Export current login items
│   ├── backup-full.yml               # Backup everything
│   ├── restore-ssh.yml               # Restore SSH keys
│   ├── restore-apps.yml              # Restore app settings
│   ├── restore-dotfiles.yml          # Restore dotfiles
│   └── selective/                    # Selective operations
│       ├── backup-apps-selective.yml
│       ├── restore-apps-selective.yml
│       └── install-app-selective.yml
├── tasks/                            # Reusable task files
│   ├── homebrew_check.yml            # Verify/update Homebrew
│   ├── install_dmg.yml               # DMG/PKG installer
│   ├── setup_ssh.yml                 # SSH key distribution
│   ├── setup_dotfiles.yml            # Dotfile distribution
│   ├── macos_baseline_settings.yml   # Baseline macOS defaults
│   ├── configure_dock.yml            # Dock configuration
│   ├── configure_login_items.yml     # Login items configuration
│   ├── restore_app_if_exists.yml     # Smart restore (installed apps only)
│   ├── restore_app.yml               # Restore from compressed backup
│   ├── restore_path.yml              # Restore with compression support
│   ├── restore_manifest_path.yml     # Restore using manifest metadata
│   ├── backup_app.yml                # Backup with compression
│   ├── backup_path.yml               # Backup file/directory
│   ├── check_network_volumes.yml     # Verify network volumes
│   └── quit_app.yml                  # Quit app before restore
├── vars/
│   └── app_backups.yml               # App backup definitions
├── docs/
│   ├── licenses.md                   # License activation
│   └── deactivation.md               # Pre-wipe checklist
├── site.yml                          # Main playbook
├── inventory.ini                     # Machine definitions
├── ansible.cfg                       # Ansible configuration
└── requirements.yml                  # Galaxy dependencies
```

## Architecture

### Self-Contained Roles

Each role handles all provisioning aspects:

- ✅ Homebrew check and update
- ✅ App installation (formulae, casks, MAS, DMG/PKG)
- ✅ SSH key distribution
- ✅ Dotfile distribution
- ✅ macOS baseline settings
- ✅ Role-specific macOS overrides (if applicable)

### Post-Tasks (After All Roles)

Applied after apps are installed:

- Dock configuration
- Login items configuration
- App settings restoration (automatic for installed apps)

### Backup System with Compression

All backups use **zstd compression** for efficient network transfers:

- **Format:** `{type}-{role}-YYYYMMDD.tar.zst`
- **Compression:** ~70-90% size reduction
- **Manifests:** JSON metadata for intelligent restoration
- **Local compression:** Happens in `/tmp`, then transferred to network

## What Gets Installed & Configured

### Studio Machine (Primary Workstation)
- **Everything** - Full creative suite and development tools
- **Creative:** Adobe CC, Affinity Suite, Blender, FontBase
- **Video:** HandBrake, DaVinci Resolve, OffShoot
- **Development:** VS Code, GitHub Desktop, Fusion 360
- **Asset Management:** Eagle, NeoFinder
- **Network:** Jump Desktop, AutoMounter, Tailscale, Resilio Sync
- **Utilities:** Raycast, Carbon Copy Cloner, LuLu, Strongbox, Loop
- **Audio:** Loopback, Ultimate Vocal Remover
- **Config:** Spotlight/Finder shortcuts disabled (for Raycast)
- **SSH:** Full keys (private + public) - can SSH to other machines
- **Dotfiles:** .zshrc, .gitconfig, starship.toml, VS Code projects
- **Fonts:** Full user font library + Adobe fonts

### Laptop Machine (Mobile Creative/Development)
- **Similar to Studio** but optimized for portability
- **Creative:** Adobe CC, Affinity Suite, Blender
- **Video:** HandBrake, DaVinci Resolve, OffShoot
- **Development:** VS Code, GitHub Desktop, CrossOver
- **Utilities:** Raycast, Carbon Copy Cloner, Tailscale, SuperWhisper
- **SSH:** Full keys (private + public)
- **Dotfiles:** Full dotfiles
- **Fonts:** Full user font library + Adobe fonts

### Editor Machine (Video Production)
- **Video:** HandBrake, OffShoot, IINA, Shutter Encoder
- **Asset Management:** Eagle, NeoFinder
- **Network:** Jump Desktop, AutoMounter, Tailscale, Resilio Sync
- **Utilities:** Slack, Affinity Suite
- **SSH:** Public keys only (SSH host mode)
- **Fonts:** User fonts + Adobe fonts

### Family Machine (Basic Use)
- **Basic Apps:** Google Chrome, Plex, Sonos, Bloom, Spotify
- **Restrictions:** Minimal toolset, simplified Dock
- **SSH:** Public keys only
- **No font management**
- **No dotfiles**

## Tag System

### Installation Methods
```bash
--tags brew          # All Homebrew (formulae + casks)
--tags formula       # CLI tools only
--tags cask          # Homebrew GUI apps
--tags mas           # Mac App Store apps
--tags dmg           # DMG/PKG installers
--tags apps          # ALL apps (brew + mas + dmg)
```

### Configuration
```bash
--tags config        # All configuration
--tags ssh           # SSH keys only
--tags dotfiles      # Dotfiles only
--tags macos_defaults # System preferences only
--tags dock          # Dock configuration only
--tags login_items   # Login items only
--tags restore       # App settings restore only
```

### Common Use Cases
```bash
# Install only Homebrew apps (fastest)
ansible-playbook site.yml -i inventory.ini --limit studio --tags brew

# Install all apps, skip all configuration
ansible-playbook site.yml -i inventory.ini --limit studio --tags apps

# Reconfigure system and restore app settings (no app installation)
ansible-playbook site.yml -i inventory.ini --limit studio --tags config

# Just restore app settings (after manual installs)
ansible-playbook site.yml -i inventory.ini --limit studio --tags restore

# Skip app settings restore (apps + system config only)
ansible-playbook site.yml -i inventory.ini --limit studio --skip-tags restore
```

## Backup & Restore System

### Backup Format

All backups use **compressed tar.zst format** with manifests:

```
/Volumes/backup_proxmox/macos/
├── ssh/
│   ├── ssh-studio-20260127.tar.zst    # Compressed SSH backup
│   └── ssh-laptop-20260127.tar.zst
├── apps/
│   ├── raycast/
│   │   └── raycast-studio-20260127.tar.zst
│   ├── vscode/
│   │   └── vscode-studio-20260127.tar.zst
│   └── user-fonts/
│       └── user-fonts-studio-20260127.tar.zst
└── dotfiles/
    ├── dotfiles-studio-20260127.tar.zst
    └── dotfiles-laptop-20260127.tar.zst
```

### Checking Backup Contents

To inspect what's inside a compressed backup without extracting:

```bash
# List contents of a tar.zst backup
zstd -d -c /Volumes/backup_proxmox/macos/apps/raycast/raycast-studio-20260127.tar.zst | tar -tf - | head -20

# View manifest.json from a backup
zstd -d -c /Volumes/backup_proxmox/macos/apps/raycast/raycast-studio-20260127.tar.zst | tar -xOf - manifest.json | jq .

# Extract just the manifest
zstd -d -c backup.tar.zst | tar -xf - manifest.json

# View full archive tree structure
zstd -d -c backup.tar.zst | tar -tf - | sort
```

### Backup Commands

```bash
# Backup everything (SSH, apps, dotfiles)
ansible-playbook playbooks/backup-full.yml -i inventory.ini --limit studio

# Backup individual components
ansible-playbook playbooks/backup-ssh.yml -i inventory.ini --limit studio
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit studio
ansible-playbook playbooks/backup-dotfiles.yml -i inventory.ini --limit studio

# Backup specific apps only
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit studio \
  -e "apps_list=raycast,vscode,resolve"

# Export current login items to YAML
ansible-playbook playbooks/backup-login-items.yml -i inventory.ini --limit studio
```

### Restore Commands

```bash
# Restore everything
ansible-playbook playbooks/restore-ssh.yml -i inventory.ini --limit studio
ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit studio
ansible-playbook playbooks/restore-dotfiles.yml -i inventory.ini --limit studio

# Restore specific apps only
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=raycast,vscode"

# Cross-role restore (e.g., restore laptop's backup to studio)
ansible-playbook playbooks/restore-ssh.yml -i inventory.ini --limit studio \
  -e "restore_from_machine=laptop"
```

### Automatic Restore During Provisioning

Settings are automatically restored for installed apps:

```bash
# Default: Apps + config + automatic restore
ansible-playbook site.yml -i inventory.ini --limit studio -K

# Skip automatic restore
ansible-playbook site.yml -i inventory.ini --limit studio -K --skip-tags restore
```

**Smart Restore:** Only apps that are actually installed get their settings restored.

## Selective App Installation

Install specific apps without running full provisioning:

```bash
# Install specific apps by name
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=spotify,typeface"

# Install and restore settings
ansible-playbook playbooks/selective/install-app-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=typeface" && \
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit studio \
  -e "apps_list=typeface"
```

The playbook automatically detects which installation method each app uses (brew formula, cask, MAS, or DMG).

## macOS System Configuration

### Baseline Settings (All Machines)

**General UI/UX:**
- Expand save/print panels by default
- Save to disk (not iCloud) by default

**Language & Region:**
- NZ English locale, metric system, Celsius

**Trackpad & Mouse:**
- Tap to click, two-finger right-click

**Keyboard & Text:**
- Disable smart quotes and dashes
- F1-F12 as standard function keys

**Finder:**
- Show all drives and servers on desktop (external drives hidden)
- Show status bar and path bar, column view
- Search current folder, show ~/Library
- No .DS_Store on network volumes

**Dock:**
- Auto-hide, minimize to app icon
- No recent apps, translucent hidden apps

**Hot Corners:**
- Top right: Desktop
- Bottom left: Sleep display

**Screenshots:**
- Save to Desktop as PNG, no shadow

**Other:**
- Photos won't auto-open
- Click wallpaper to reveal desktop disabled

### Role-Specific Overrides

**Studio & Laptop:**
- Spotlight (Cmd+Space) disabled - frees for Raycast
- Finder search (Cmd+Option+Space) disabled

⚠️ **Requires logout** for keyboard shortcuts to take effect.

## Dock & Login Items

### Dock Configuration

Defined in `group_vars/{machine_type}.yml`:

```yaml
studio_dock_clear_all: true

studio_dock_apps:
  - path: "/Applications/Bloom.app"
  - path: "/Applications/Brave Browser.app"
  - path: "/System/Applications/Messages.app"

studio_dock_folders:
  - path: "~/Downloads"
    view: fan
    display: folder
    sort: dateadded
```

### Login Items

```yaml
studio_login_items:
  - name: "Raycast"
    path: "/Applications/Raycast.app"
    hidden: false
  
  - name: "AutoMounter"
    path: "/Applications/AutoMounter.app"
    hidden: true

studio_remove_login_items:
  - "Spotify"
```

Export current login items:
```bash
ansible-playbook playbooks/backup-login-items.yml -i inventory.ini --limit studio
```

## Network Storage Integration

All machines use `/Volumes/backup_proxmox/macos/` for:

- **SSH keys** - All machines get public keys; studio/laptop get private keys
- **App settings** - Compressed backups with manifests
- **Dotfiles** - Studio/Laptop only
- **Fonts** - User fonts and Adobe fonts (via app_backups.yml)
- **Licenses** - See `docs/licenses.md`

**SSH Key Strategy:**
- **Studio/Laptop:** Full private + public keys (can SSH to other machines)
- **Editor/Family:** Public keys only (SSH host mode)

**Required:** Mount `/Volumes/backup_proxmox` before running.

## Adding Apps

Edit `group_vars/{machine_type}.yml`:

```yaml
studio_formula_apps:
  - newtool

studio_cask_apps:
  - new-app

studio_mas_apps:
  - { id: 123456, name: 'App Name' }

studio_dmg_pkg_apps:
  - name: "MyApp"
    url: "/Volumes/backup_proxmox/macos/installers/MyApp.dmg"
    volume: "MyApp Installer"
```

## Adding App Backups

1. **Discover settings locations:**
   ```bash
   ./scripts/discover-app-files.sh "App Name"
   ```

2. **Add to `vars/app_backups.yml`:**
   ```yaml
   myapp:
     name: "My Application"
     paths:
       # File - include filename in dest
       - src: "~/Library/Preferences/com.example.app.plist"
         dest: "myapp/com.example.app.plist"
       
       # Directory - no trailing slash
       - src: "~/Library/Application Support/MyApp"
         dest: "myapp/application-support"
         exclude:
           - "Cache"
           - "Logs"
   ```

3. **Add to machine-specific list:**
   ```yaml
   studio_apps_to_backup:
     - myapp
   ```

## Utilities

### Software Audit
```bash
./scripts/mac-software-audit.sh
```

### Discover App Settings
```bash
./scripts/discover-app-files.sh "App Name"
```

### Manage Login Items
```bash
./scripts/manage-login-items.sh list
./scripts/manage-login-items.sh add Raycast
./scripts/manage-login-items.sh add-hidden AutoMounter
```

### Create New Role
```bash
./scripts/create-role.sh newrole "New Machine Type"
```

## Requirements

- macOS 11.0+ (Big Sur or later)
- Xcode Command Line Tools (installed by bootstrap.sh)
- Homebrew (installed by bootstrap.sh)
- Network access for downloads
- Network storage at `/Volumes/backup_proxmox` for backups

## Troubleshooting

**Homebrew not found:**
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"  # Apple Silicon
eval "$(/usr/local/bin/brew shellenv)"     # Intel
```

**Network volume not mounted:**
```bash
# Mount via Finder: Cmd+K → smb://your-server/backup_proxmox
```

**Check backup contents:**
```bash
# List files in backup
zstd -d -c backup.tar.zst | tar -tf - | head -20

# View manifest
zstd -d -c backup.tar.zst | tar -xOf - manifest.json | jq .
```

**Permission denied:**
```bash
sudo -n true && echo "OK" || echo "Not configured"
```

**Keyboard shortcuts not working:**
Log out and back in for changes to take effect.

## Documentation

- [Quick Reference Guide](quick_reference.md) - Common commands
- [License Management](docs/licenses.md) - Activation instructions
- [Deactivation Checklist](docs/deactivation.md) - Before wiping a machine

## License

Personal project - use at your own risk.