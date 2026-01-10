# macOS Provisioning with Ansible

Automated macOS setup using Ansible for consistent machine provisioning across Personal, Video Production, and Family configurations. Includes application installation, system configuration, and automatic settings restore.

## Quick Start

### First-Time Setup

```bash
# Run bootstrap script (installs prerequisites and clones repo)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/timoparsons/ansible-macos/main/scripts/bootstrap.sh)"

# The script will automatically run setup.sh which prompts you to choose:
# 1) Personal (Full setup + Video tools)
# 2) Video Production (Work focused)
# 3) Family (Basic + Restrictions)
```

The provisioning will:
1. Install all applications (Homebrew, Mac App Store, DMG/PKG)
2. Configure macOS system preferences
3. Set up the Dock
4. **Automatically restore app settings for installed apps** (from network backup)

⚠️ **Important:** Log out and back in after provisioning for keyboard shortcuts to take effect.

### Manual Run

```bash
cd ~/mac-setup
./scripts/setup.sh
```

### Using Ansible Directly

```bash
# Full provision (apps + config + restore settings)
ansible-playbook site.yml -i inventory.ini --limit personal -K

# Install apps only, skip configuration
ansible-playbook site.yml -i inventory.ini --limit personal --tags apps

# Install apps + restore settings, skip system config
ansible-playbook site.yml -i inventory.ini --limit personal --tags apps,restore

# Just restore app settings (useful after manual installs)
ansible-playbook site.yml -i inventory.ini --limit personal --tags restore
```

## Project Structure

```
ansible-macos/
├── scripts/
│   ├── bootstrap.sh              # First-run setup (Homebrew, Git, Auth)
│   ├── setup.sh                  # Main provisioning orchestrator
│   └── mac-software-audit.sh     # Audit existing apps
├── roles/
│   ├── common/                   # Apps/config for all machines
│   │   ├── tasks/
│   │   │   ├── macos_settings.yml    # Baseline macOS defaults
│   │   │   └── dock.yml              # Dock configuration
│   │   └── handlers/             # Service restart handlers
│   ├── personal/                 # Personal machine specifics
│   │   ├── tasks/
│   │   │   └── macos_settings.yml    # Personal overrides (Spotlight, etc)
│   │   └── handlers/             # Personal-specific handlers
│   ├── video/                    # Video production tools
│   └── family/                   # Family machine restrictions
├── group_vars/
│   ├── all.yml                   # Global variables
│   ├── personal.yml              # Personal machine config
│   ├── video.yml                 # Video machine config
│   └── family.yml                # Family machine config
├── playbooks/
│   ├── backup-ssh.yml            # Backup SSH keys
│   ├── backup-apps.yml           # Backup app settings
│   ├── restore-apps.yml          # Restore app settings
│   └── selective/                # Selective backup/restore
│       ├── backup-apps-selective.yml
│       └── restore-apps-selective.yml
├── tasks/                        # Reusable task files
│   ├── restore_app_if_exists.yml # Smart restore (only installed apps)
│   ├── restore_single_app.yml
│   └── backup_single_app.yml
├── vars/
│   └── app_backups.yml           # App backup definitions
├── site.yml                      # Main playbook
└── inventory.ini                 # Machine definitions
```

## What Gets Installed & Configured

### Common (All Machines)
- **CLI Tools:** dockutil, git, mas
- **Apps:** Affinity Suite, Loop, Spotify, VLC, WhatsApp
- **System Config:** 
  - macOS defaults (NZ locale, trackpad, keyboard, Finder, Dock, screenshots, etc.)
  - Dock configuration
  - App settings restore (automatic for installed apps)

### Personal Machine
- **Development:** VS Code, GitHub Desktop
- **Creative:** Adobe CC, Blender, FontBase
- **Video:** HandBrake, DaVinci Resolve (via Video role)
- **Utilities:** Raycast, Carbon Copy Cloner, Tailscale
- **Config:** Spotlight/Finder keyboard shortcuts disabled (for Raycast)

### Video Production Machine
- **Video:** HandBrake, OffShoot, IINA
- **Asset Management:** Eagle, NeoFinder
- **Network:** Jump Desktop, AutoMounter

### Family Machine
- **Basic Apps:** Google Chrome, Plex, Sonos
- **Restrictions:** Minimal toolset, simplified Dock

## Tag System

Control exactly what gets installed/configured:

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
--tags config        # All configuration (ssh, dotfiles, macos_defaults, dock, restore)
--tags ssh           # SSH keys only
--tags dotfiles      # Dotfiles only
--tags macos_defaults # System preferences only
--tags dock          # Dock configuration only
--tags restore       # App settings restore only
```

### Common Use Cases
```bash
# Install only Homebrew apps (fastest)
ansible-playbook site.yml -i inventory.ini --limit personal --tags brew

# Install all apps, skip all configuration
ansible-playbook site.yml -i inventory.ini --limit personal --tags apps

# Reconfigure system and restore app settings (no app installation)
ansible-playbook site.yml -i inventory.ini --limit personal --tags config

# Just restore app settings (e.g., after manual app installs)
ansible-playbook site.yml -i inventory.ini --limit personal --tags restore

# Skip app settings restore (apps + system config only)
ansible-playbook site.yml -i inventory.ini --limit personal --skip-tags restore

# Skip slow DMG installations
ansible-playbook site.yml -i inventory.ini --limit personal --skip-tags dmg

# Install everything except Mac App Store
ansible-playbook site.yml -i inventory.ini --limit personal --skip-tags mas
```

## macOS System Configuration

The playbook automatically configures macOS system preferences using the `osx_defaults` module for reliability and idempotency. All machines receive baseline settings, with role-specific overrides available.

### Baseline Settings (All Machines)

**General UI/UX:**
- Expand save/print panels by default
- Save to disk (not iCloud) by default

**Language & Region:**
- NZ English locale and measurement units
- Metric system, Celsius

**Trackpad & Mouse:**
- Tap to click enabled
- Two-finger right-click

**Keyboard & Text:**
- Disable smart quotes and dashes (better for coding)
- F1-F12 as standard function keys (not media controls)

**Finder:**
- Show all drives, servers, and removable media on desktop
- Show status bar and path bar
- Column view by default
- Search current folder (not "This Mac")
- Show ~/Library folder
- No .DS_Store files on network volumes
- Spring loading enabled

**Dock:**
- Auto-hide enabled
- Minimize to application icon
- No recent apps
- Translucent hidden apps

**Hot Corners:**
- Top right: Desktop
- Bottom left: Sleep display

**Screenshots:**
- Save to Desktop as PNG
- No shadow

**Other:**
- Photos app won't auto-open when devices plugged in
- Disable click wallpaper to reveal desktop

### Personal Machine Overrides

**Keyboard Shortcuts:**
- Spotlight (Cmd+Space) disabled - frees it for Raycast
- Finder search (Cmd+Option+Space) disabled

⚠️ **Requires logout** for keyboard shortcuts to take effect.

### Modifying Settings

Edit `roles/common/tasks/macos_settings.yml` for baseline settings, or create `roles/{machine_type}/tasks/macos_settings.yml` for role-specific overrides.

### Testing macOS Defaults

```bash
# Apply only macOS system preferences
ansible-playbook site.yml -i inventory.ini --limit personal --tags macos_defaults

# Dry run to see what would change
ansible-playbook site.yml -i inventory.ini --limit personal --tags macos_defaults --check
```

## Application Settings Backup & Restore

Application settings are automatically backed up to and restored from network storage at `/Volumes/backup_proxmox/macos/apps/{machine_type}/`.

### Automatic Restore During Provisioning

When you run the main playbook, app settings are **automatically restored** for any apps that are installed:

```bash
# Full provision - apps are installed, then settings restored
ansible-playbook site.yml -i inventory.ini --limit personal -K

# Skip automatic restore
ansible-playbook site.yml -i inventory.ini --limit personal -K --skip-tags restore
# OR
ansible-playbook site.yml -i inventory.ini --limit personal -K -e "restore_app_settings=false"
```

**Smart Restore:** Only apps that are actually installed get their settings restored. Apps that failed to install or were skipped are automatically skipped during restore.

### Manual Restore (After Installing Apps Manually)

If you install apps manually after the initial provisioning, restore their settings:

```bash
# Restore settings for all installed apps
ansible-playbook site.yml -i inventory.ini --limit personal --tags restore

# Restore specific apps only
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit personal -e "apps_list=raycast,vscode"
```

### Backup Commands

```bash
# Backup SSH keys
ansible-playbook playbooks/backup-ssh.yml -i inventory.ini --limit personal

# Backup all app settings
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit personal

# Backup specific apps
ansible-playbook playbooks/selective/backup-apps-selective.yml \
  -i inventory.ini --limit personal -e "apps_list=raycast,vscode"
```

### Viewing Available Apps

To see which apps have backup definitions:

```bash
# View app_backup_definitions in vars/app_backups.yml
cat vars/app_backups.yml | grep -A1 "^  [a-z-]*:" | grep "name:"

# Or check which apps are backed up for your machine type
grep -A50 "personal_apps_to_backup:" vars/app_backups.yml
```

## Network Storage Integration

Personal and Video machines use network storage for:
- SSH key distribution
- Application setting backups
- Dotfile synchronization
- **License storage** (see `docs/licenses.md`)

**Required:** Mount `/Volumes/backup_proxmox` before running.

**License Management:** 
- Licenses stored at `/Volumes/backup_proxmox/macos/licenses/`
- See [docs/licenses.md](docs/licenses.md) for activation instructions
- See [docs/deactivation.md](docs/deactivation.md) before wiping machine

## Customization

### Adding Apps

Edit the appropriate group_vars file:

```yaml
# group_vars/personal.yml

personal_formula_apps:
  - newtool

personal_cask_apps:
  - new-app

personal_mas_apps:
  - { id: 123456, name: 'App Name' }

personal_dmg_pkg_apps:
  - name: "MyApp"
    url: "/path/to/installer.dmg"
    volume: "MyApp Installer"
```

### Adding App Backups

Edit `vars/app_backups.yml`:

```yaml
app_backup_definitions:
  myapp:
    name: "My Application"
    paths:
      - src: "~/Library/Application Support/MyApp"
        dest: "myapp"
        exclude:
          - "Cache"
          - "Logs"
```

Then add to machine-specific backup list:
```yaml
personal_apps_to_backup:
  - myapp
```

## Utilities

### Software Audit
Identify apps that could be managed by Homebrew:
```bash
./scripts/mac-software-audit.sh
# Creates: mac_software_audit.txt
```

### List All Tags
```bash
ansible-playbook site.yml -i inventory.ini --limit personal --list-tags
```

### Dry Run
```bash
ansible-playbook site.yml -i inventory.ini --limit personal --check
```

## Requirements

- macOS 11.0+ (Big Sur or later)
- Xcode Command Line Tools (installed by bootstrap.sh)
- Homebrew (installed by bootstrap.sh)
- Network access for downloads
- (Optional) Network storage at `/Volumes/backup_proxmox` for backups/SSH

## Notes

- **First run:** Bootstrap handles GitHub authentication and passwordless sudo
- **Idempotent:** Safe to run multiple times
- **Network volumes:** Personal/Video machines check for mounted volumes before running
- **DMG installations:** Slower than Homebrew, consider using `--skip-tags dmg` for faster testing
- **Mac App Store:** Requires Apple ID to be logged in
- **Logout required:** Keyboard shortcut changes need logout to take effect

## Troubleshooting

**Homebrew not found:**
```bash
# Ensure Homebrew is in PATH
eval "$(/opt/homebrew/bin/brew shellenv)"  # Apple Silicon
eval "$(/usr/local/bin/brew shellenv)"     # Intel
```

**Network volume not mounted:**
```bash
# Mount manually via Finder
Cmd+K → smb://your-server/backup_proxmox
```

**DMG installation failed:**
```bash
# Retry just DMG installations with verbose output
ansible-playbook site.yml -i inventory.ini --limit personal --tags dmg -v
```

**Permission denied:**
```bash
# Verify passwordless sudo is configured
sudo -n true && echo "OK" || echo "Not configured"
```

**Keyboard shortcuts not working:**
```bash
# Log out and back in for changes to take effect
# This is required for Spotlight/Finder shortcut changes
```

## License

Personal project - use at your own risk.

