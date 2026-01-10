# macOS Provisioning with Ansible

Automated macOS setup using Ansible for consistent machine provisioning across Personal, Video Production, and Family configurations.

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

### Manual Run

```bash
cd ~/mac-setup
./scripts/setup.sh
```

### Using Ansible Directly

```bash
# Full provision
ansible-playbook site.yml -i inventory.ini --limit personal -K

# Install only apps
ansible-playbook site.yml -i inventory.ini --limit personal --tags apps

# Only configuration
ansible-playbook site.yml -i inventory.ini --limit personal --tags config
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
│   ├── personal/                 # Personal machine specifics
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
│   └── restore-apps.yml          # Restore app settings
├── tasks/                        # Reusable task files
├── vars/
│   └── app_backups.yml           # App backup definitions
├── site.yml                      # Main playbook
└── inventory.ini                 # Machine definitions
```

## What Gets Installed

### Common (All Machines)
- **CLI Tools:** dockutil, git, mas
- **Apps:** Affinity Suite, Loop, Spotify, VLC, WhatsApp
- **System:** macOS defaults, Dock configuration

### Personal Machine
- **Development:** VS Code, GitHub Desktop
- **Creative:** Adobe CC, Blender, FontBase
- **Video:** HandBrake, DaVinci Resolve (via Video role)
- **Utilities:** Raycast, Carbon Copy Cloner, Tailscale

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
```

### Application Types
```bash
--tags cli           # Command-line tools
--tags gui           # GUI applications
```

### Configuration
```bash
--tags config        # All configuration tasks
--tags ssh           # SSH keys only
--tags dotfiles      # Dotfiles only
--tags macos_defaults # System preferences
--tags dock          # Dock configuration
```

### Common Use Cases
```bash
# Install only Homebrew apps (fastest)
ansible-playbook site.yml -i inventory.ini --limit personal --tags brew

# Install all apps, skip configuration
ansible-playbook site.yml -i inventory.ini --limit personal --tags apps

# Reconfigure Dock after manual installs
ansible-playbook site.yml -i inventory.ini --limit personal --tags dock

# Skip slow DMG installations
ansible-playbook site.yml -i inventory.ini --limit personal --skip-tags dmg

# Install everything except Mac App Store
ansible-playbook site.yml -i inventory.ini --limit personal --skip-tags mas
```

## Network Storage Integration

Personal and Video machines use network storage for:
- SSH key distribution
- Application setting backups
- Dotfile synchronization

**Required:** Mount `/Volumes/backup_proxmox` before running.

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

### Restore Commands
```bash
# Restore all app settings
ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit personal

# Restore specific apps
ansible-playbook playbooks/selective/restore-apps-selective.yml \
  -i inventory.ini --limit personal -e "apps_list=raycast,vscode"
```

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

### Modifying macOS Defaults

Edit `roles/common/files/macos-defaults.sh` for global changes, or create role-specific scripts at `roles/{role}/files/macos-defaults.sh`.

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

## License

Personal project - use at your own risk.

## Author

Tim Parsons
