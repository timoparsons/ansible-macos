# macOS Provisioning with Ansible

Automated macOS setup using Ansible for consistent machine provisioning across Personal, Video Production, and Family configurations. Includes application installation, system configuration, and automatic settings backup/restore.

## Quick Start

### First-Time Setup

```bash
# Run bootstrap script (installs prerequisites and clones repo)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/timoparsons/ansible-macos/main/scripts/bootstrap.sh)"
```

### Full Setup – Manual Run

```bash
cd ~/mac-setup
./scripts/setup.sh
```

The provisioning will:
1. Install all applications (Homebrew, Mac App Store, DMG/PKG)
2. Configure macOS system preferences
3. Set up the Dock and login items
4. **Automatically restore app settings, fonts, SSH keys, and dotfiles** (from network backup)

⚠️ **Important:** Log out and back in after provisioning for keyboard shortcuts to take effect.

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

# Skip automatic restore during provisioning
ansible-playbook site.yml -i inventory.ini --limit personal -K --skip-tags restore
```

## Project Structure

```
ansible-macos/
├── scripts/
│   ├── bootstrap.sh                  # First-run setup (Homebrew, Git, Auth)
│   ├── setup.sh                      # Main provisioning orchestrator
│   ├── mac-software-audit.sh         # Audit existing apps
│   ├── discover-app-files.sh         # Find app settings locations
│   └── manage-login-items.sh         # Manage login items manually
├── roles/
│   ├── common/                       # [DEPRECATED - now in each role]
│   ├── personal/                     # Personal machine (self-contained)
│   │   ├── tasks/
│   │   │   ├── main.yml              # Main task orchestrator
│   │   │   └── macos_settings.yml    # Personal-specific macOS overrides
│   │   └── handlers/                 # System restart handlers
│   ├── video/                        # Video production (self-contained)
│   │   ├── tasks/
│   │   │   └── main.yml              # Main task orchestrator
│   │   └── handlers/
│   └── family/                       # Family machine (self-contained)
│       ├── tasks/
│       │   └── main.yml              # Main task orchestrator
│       └── handlers/
├── group_vars/
│   ├── all.yml                       # Global variables (network paths, SSH)
│   ├── personal.yml                  # Personal apps, dock, login items
│   ├── video.yml                     # Video apps, dock, login items
│   └── family.yml                    # Family apps, dock, login items
├── playbooks/
│   ├── backup-ssh.yml                # Backup SSH keys
│   ├── backup-apps.yml               # Backup app settings
│   ├── backup-dotfiles.yml           # Backup dotfiles
│   ├── backup-fonts.yml              # Backup user fonts
│   ├── backup-login-items.yml        # Export current login items
│   ├── backup-full.yml               # Backup everything
│   ├── restore-ssh.yml               # Restore SSH keys
│   ├── restore-apps.yml              # Restore app settings
│   ├── restore-dotfiles.yml          # Restore dotfiles
│   ├── restore-fonts.yml             # Restore user fonts
│   └── selective/                    # Selective backup/restore
│       ├── backup-apps-selective.yml
│       └── restore-apps-selective.yml
├── tasks/                            # Reusable task files
│   ├── homebrew_check.yml            # Verify/update Homebrew
│   ├── install_dmg.yml               # DMG/PKG installer
│   ├── setup_ssh.yml                 # SSH key distribution
│   ├── setup_dotfiles.yml            # Dotfile distribution
│   ├── macos_baseline_settings.yml   # Baseline macOS defaults
│   ├── configure_dock.yml            # Dock configuration
│   ├── configure_login_items.yml     # Login items configuration
│   ├── restore_app_if_exists.yml     # Smart restore (only installed apps)
│   ├── restore_app.yml               # Restore single app
│   ├── restore_path.yml              # Restore file/directory with compression support
│   ├── restore_fonts.yml             # Restore fonts from backup
│   ├── backup_app.yml                # Backup single app
│   ├── backup_path.yml               # Backup file/directory
│   ├── backup_compressed_directory.yml # Backup with zstd compression
│   ├── check_network_volumes.yml     # Verify network volumes mounted
│   └── quit_app.yml                  # Quit app before restore
├── vars/
│   └── app_backups.yml               # App backup definitions (all apps)
├── docs/
│   ├── licenses.md                   # License activation instructions
│   └── deactivation.md               # Pre-wipe deactivation checklist
├── site.yml                          # Main playbook
├── inventory.ini                     # Machine definitions
├── ansible.cfg                       # Ansible configuration
└── requirements.yml                  # Ansible Galaxy dependencies
```

## Architecture Changes (v2.0)

### Self-Contained Roles

Each role is **self-contained** and handles all aspects of provisioning:

- ✅ Homebrew check and update
- ✅ App installation (brew formulae, casks, MAS, DMG/PKG)
- ✅ SSH key distribution
- ✅ Dotfile distribution
- ✅ macOS baseline settings (from `tasks/macos_baseline_settings.yml`)
- ✅ Role-specific macOS overrides (if applicable)
- ✅ Font restoration (if enabled)

### Post-Tasks (Applied After Roles)

These run after all roles complete since they require apps to be installed:

- Dock configuration
- Login items configuration
- App settings restoration (automatic for installed apps)

## What Gets Installed & Configured

### Common (All Machines)
- **CLI Tools:** dockutil, git, mas, zstd
- **Apps:** Affinity Suite, Bloom, Ice, Loop, Spotify, VLC, WhatsApp
- **System Config:** 
  - macOS defaults (NZ locale, trackpad, keyboard, Finder, Dock, screenshots, etc.)
  - Dock configuration
  - Login items
  - App settings restore (automatic for installed apps)
  - SSH keys (public keys for all machines, private keys for personal only)
  - Fonts (personal/video only)

### Personal Machine
- **Everything from video role** (personal includes all video tools)
- **Development:** VS Code, GitHub Desktop
- **Creative:** Adobe CC, Blender, FontBase, Affinity Suite
- **Video:** HandBrake, DaVinci Resolve, OffShoot
- **Utilities:** Raycast, Carbon Copy Cloner, Tailscale, Strongbox, LuLu
- **Config:** Spotlight/Finder keyboard shortcuts disabled (for Raycast)
- **SSH:** Full keys (private + public)
- **Dotfiles:** .zshrc, .gitconfig, starship.toml, etc.

### Video Production Machine
- **Video:** HandBrake, OffShoot, IINA, DaVinci Resolve
- **Asset Management:** Eagle, NeoFinder
- **Network:** Jump Desktop, AutoMounter
- **SSH:** Public keys only (can be accessed from personal machine)

### Family Machine
- **Basic Apps:** Google Chrome, Plex, Sonos, Bloom
- **Restrictions:** Minimal toolset, simplified Dock
- **SSH:** Public keys only

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
--tags config        # All configuration (ssh, dotfiles, macos_defaults, dock, login_items, restore)
--tags ssh           # SSH keys only
--tags dotfiles      # Dotfiles only
--tags macos_defaults # System preferences only
--tags dock          # Dock configuration only
--tags login_items   # Login items only
--tags fonts         # Font restoration only
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


### Modifying Settings

Edit `tasks/macos_baseline_settings.yml` for baseline settings, or create `roles/{machine_type}/tasks/macos_settings.yml` for role-specific overrides.

### Testing macOS Defaults

```bash
# Apply only macOS system preferences
ansible-playbook site.yml -i inventory.ini --limit personal --tags macos_defaults

# Dry run to see what would change
ansible-playbook site.yml -i inventory.ini --limit personal --tags macos_defaults --check
```

## Dock & Login Items Configuration

### Dock Configuration

Each machine type can define its own dock layout in `group_vars/{machine_type}.yml`:

```yaml
personal_dock_clear_all: true  # Remove all existing dock items first

personal_dock_apps:
  - path: "/Applications/Bloom.app"
  - path: "/Applications/Brave Browser.app"
  - path: "/System/Applications/Messages.app"

personal_dock_folders:
  - path: "~/Downloads"
    view: fan
    display: folder
    sort: dateadded
```

### Login Items Configuration

Configure apps to launch at login:

```yaml
personal_login_items:
  - name: "Raycast"
    path: "/Applications/Raycast.app"
    hidden: false
  
  - name: "AutoMounter"
    path: "/Applications/AutoMounter.app"
    hidden: true

personal_remove_login_items:
  - "Spotify"  # Remove if present
```

To export your current login items to YAML:

```bash
ansible-playbook playbooks/backup-login-items.yml -i inventory.ini --limit personal
```

## Application Settings Backup & Restore

Application settings are automatically backed up to and restored from network storage at `/Volumes/backup_proxmox/macos/apps/`.

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

### Backup & Restore Commands

See the [Quick Reference Guide](QUICK_REFERENCE.md) for detailed examples.

**Quick examples:**

```bash
# Backup everything
ansible-playbook playbooks/backup-ssh.yml -i inventory.ini --limit personal
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit personal
ansible-playbook playbooks/backup-dotfiles.yml -i inventory.ini --limit personal
ansible-playbook playbooks/backup-fonts.yml -i inventory.ini --limit personal

# Restore everything
ansible-playbook playbooks/restore-ssh.yml -i inventory.ini --limit personal
ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit personal
ansible-playbook playbooks/restore-dotfiles.yml -i inventory.ini --limit personal
ansible-playbook playbooks/restore-fonts.yml -i inventory.ini --limit personal

# Restore specific apps only
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit personal -e "apps_list=raycast,vscode"
```

### Compression Support

Large app directories (like CrossOver bottles) can be compressed during backup:

```yaml
crossover:
  name: "CrossOver"
  paths:
    - src: "~/Applications/CrossOver"
      dest: "crossover/applications"
      compress: true  # Creates .tar.zst archive
```

Compressed backups are automatically detected and extracted during restore.

### Viewing Available Apps

To see which apps have backup definitions:

```bash
# View all apps in vars/app_backups.yml
grep -E "^  [a-z-]+:" vars/app_backups.yml

# Check which apps are backed up for your machine type
grep -A50 "personal_apps_to_backup:" vars/app_backups.yml
```

### Adding New App Backups

1. **Discover app settings locations:**
   ```bash
   ./scripts/discover-app-files.sh "App Name"
   ```

2. **Add to `vars/app_backups.yml`:**
   ```yaml
   app_backup_definitions:
     myapp:
       name: "My Application"
       paths:
         # For files - include filename in dest
         - src: "~/Library/Preferences/com.example.app.plist"
           dest: "myapp/com.example.app.plist"
         
         # For directories - no trailing slash
         - src: "~/Library/Application Support/MyApp"
           dest: "myapp/application-support"
           exclude:
             - "Cache"
             - "Logs"
         
         # For large directories - use compression
         - src: "~/Library/Large/Directory"
           dest: "myapp/large-data"
           compress: true
   ```

3. **Add to machine-specific backup list:**
   ```yaml
   personal_apps_to_backup:
     - myapp
   ```

## Network Storage Integration

All machines use network storage at `/Volumes/backup_proxmox/macos/` for:

- **SSH key distribution** - All machines get public keys for SSH access
- **Application setting backups** (Personal/Video)
- **Dotfile synchronization** (Personal)
- **Font backups** (Personal/Video)
- **License storage** (see `docs/licenses.md`)

**SSH Key Strategy:**
- **All machines** receive public keys (`id_ed25519.pub`, `id_rsa.pub`, `authorized_keys`) from personal backup
- **Personal machine only** receives private keys (`id_ed25519`, `id_rsa`, `config`)
- This allows SSH access to video/family machines from personal machine

**Required:** Mount `/Volumes/backup_proxmox` before running provisioning or backup/restore playbooks.

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
    url: "/Volumes/backup_proxmox/macos/installers/MyApp.dmg"
    volume: "MyApp Installer"
```

### Adding to Dock/Login Items

See examples in `group_vars/{machine_type}.yml` for dock and login items configuration.

## Utilities

### Software Audit
Identify apps that could be managed by Homebrew:
```bash
./scripts/mac-software-audit.sh
# Creates: mac_software_audit.txt
```

### Discover App Settings
Find where an app stores its settings:
```bash
./scripts/discover-app-files.sh "App Name"
# Creates: app-discovery-App-Name.txt
```

### Manage Login Items
Manually add/remove login items:
```bash
./scripts/manage-login-items.sh list
./scripts/manage-login-items.sh add Raycast
./scripts/manage-login-items.sh add-hidden "Carbon Copy Cloner"
./scripts/manage-login-items.sh remove Raycast
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
- **Compression:** Large app directories can use zstd compression for faster network transfers

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

**App settings not restoring:**
```bash
# Check if backup exists
ls -la /Volumes/backup_proxmox/macos/apps/

# Manually restore settings
ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit personal
```

**Compressed restore fails:**
```bash
# Ensure zstd is installed
brew install zstd

# Verify compressed backup exists
ls -la /Volumes/backup_proxmox/macos/apps/*.tar.zst
```

## Documentation

- [Quick Reference Guide](QUICK_REFERENCE.md) - Command examples and common tasks
- [License Management](docs/licenses.md) - Activation instructions
- [Deactivation Checklist](docs/deactivation.md) - Before wiping a machine

## License

Personal project - use at your own risk.