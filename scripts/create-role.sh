#!/bin/bash
# scripts/create-role.sh
# Quick script to scaffold a new machine role

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <role-name> [description]"
    echo "Example: $0 studio 'Studio Machine'"
    exit 1
fi

ROLE_NAME="$1"
ROLE_DESC="${2:-$ROLE_NAME Machine}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."

echo "🚀 Creating new role: $ROLE_NAME"
echo "   Description: $ROLE_DESC"
echo ""

# 1. Create role directory structure
echo "📁 Creating role directory..."
mkdir -p "$REPO_ROOT/roles/$ROLE_NAME/tasks"
mkdir -p "$REPO_ROOT/roles/$ROLE_NAME/handlers"

# 2. Create main.yml from template
cat > "$REPO_ROOT/roles/$ROLE_NAME/tasks/main.yml" << 'EOF'
---
# ============================================================================
# FILE: roles/ROLE_NAME/tasks/main.yml
# ============================================================================

# ============================================================================
# PREREQUISITES
# ============================================================================

- name: Check Homebrew and update
  include_tasks: "{{ playbook_dir }}/tasks/homebrew_check.yml"
  tags: ['always']

# ============================================================================
# APPLICATIONS
# ============================================================================

- name: Install ROLE_NAME formula apps
  community.general.homebrew:
    name: "{{ ROLE_NAME_formula_apps }}"
    state: present
  when: ROLE_NAME_formula_apps is defined and ROLE_NAME_formula_apps | length > 0
  tags: ['brew', 'formula', 'cli', 'apps']

- name: Install ROLE_NAME cask apps
  community.general.homebrew_cask:
    name: "{{ ROLE_NAME_cask_apps }}"
    state: present
  when: ROLE_NAME_cask_apps is defined and ROLE_NAME_cask_apps | length > 0
  tags: ['brew', 'cask', 'gui', 'apps']

- name: Install ROLE_NAME Mac App Store apps
  community.general.mas:
    id: "{{ item.id }}"
    state: present
  loop: "{{ ROLE_NAME_mas_apps }}"
  when: ROLE_NAME_mas_apps is defined and ROLE_NAME_mas_apps | length > 0
  tags: ['mas', 'gui', 'apps']

- name: Install ROLE_NAME apps from DMG/PKG files
  include_tasks: "{{ playbook_dir }}/tasks/install_dmg.yml"
  loop: "{{ ROLE_NAME_dmg_pkg_apps }}"
  loop_control:
    loop_var: dmg_item
    label: "{{ dmg_item.name }}"
  when: ROLE_NAME_dmg_pkg_apps is defined and ROLE_NAME_dmg_pkg_apps | length > 0
  tags: ['dmg', 'gui', 'apps']

# ============================================================================
# SSH
# ============================================================================

- name: Setup SSH keys
  include_tasks: "{{ playbook_dir }}/tasks/setup_ssh.yml"
  when: ssh_files is defined and ssh_files | length > 0
  tags: ['ssh', 'config']

# ============================================================================
# DOTFILES
# ============================================================================

- name: Setup dotfiles
  include_tasks: "{{ playbook_dir }}/tasks/setup_dotfiles.yml"
  when: macos_network_base is defined
  tags: ['dotfiles', 'config']

# ============================================================================
# MACOS SETTINGS
# ============================================================================

- name: Apply baseline macOS settings
  include_tasks: "{{ playbook_dir }}/tasks/macos_baseline_settings.yml"
  tags: ['macos_defaults', 'config']

# Uncomment if role needs custom macOS overrides:
# - name: Apply ROLE_NAME macOS settings overrides
#   include_tasks: macos_settings.yml
#   tags: ['macos_defaults', 'config']

# ============================================================================
# FONTS
# ============================================================================

- name: Restore user fonts
  include_tasks: "{{ playbook_dir }}/tasks/restore_fonts.yml"
  when: 
    - restore_fonts | default(true)
    - macos_network_base is defined
    - not ansible_check_mode  
  tags: ['fonts', 'restore', 'config']
EOF

# Replace ROLE_NAME placeholders
sed -i '' "s/ROLE_NAME/$ROLE_NAME/g" "$REPO_ROOT/roles/$ROLE_NAME/tasks/main.yml"

# 3. Create handlers/main.yml
cat > "$REPO_ROOT/roles/$ROLE_NAME/handlers/main.yml" << 'EOF'
---
# roles/ROLE_NAME/handlers/main.yml

- name: Refresh Preferences
  ansible.builtin.shell: killall cfprefsd
  failed_when: false

- name: Restart Dock
  ansible.builtin.shell: killall Dock
  failed_when: false

- name: Restart Finder
  ansible.builtin.shell: killall Finder
  failed_when: false

- name: Restart SystemUIServer
  ansible.builtin.shell: killall SystemUIServer
  failed_when: false
EOF

sed -i '' "s/ROLE_NAME/$ROLE_NAME/g" "$REPO_ROOT/roles/$ROLE_NAME/handlers/main.yml"

# 4. Create group_vars
cat > "$REPO_ROOT/group_vars/$ROLE_NAME.yml" << 'EOF'
# group_vars/ROLE_NAME.yml

# ============================================================================
# Restore and configuration flags
# ============================================================================
restore_app_settings: true
restore_fonts: true
configure_dock: true
configure_login_items: true

# ============================================================================
# Applications
# ============================================================================

# Command Line Tools (Brew Formulae)
ROLE_NAME_formula_apps:
  - dockutil
  - git
  - mas
  - zstd

# GUI Applications (Brew Casks)
ROLE_NAME_cask_apps:
  - bloom
  - jordanbaird-ice
  - loop
  - spotify
  - vlc
  - whatsapp

# Mac App Store (MAS)
ROLE_NAME_mas_apps: []

# DMG/PKG apps
ROLE_NAME_dmg_pkg_apps: []

# ============================================================================
# Dock Configuration
# ============================================================================

ROLE_NAME_dock_clear_all: true

ROLE_NAME_dock_apps:
  - path: "/Applications/Bloom.app"
  - path: "/System/Applications/Messages.app"
  - path: "/System/Applications/System Settings.app"

ROLE_NAME_dock_folders: []

# ============================================================================
# Login Items
# ============================================================================

ROLE_NAME_login_items:
  - name: "Bloom"
    path: "/Applications/Bloom.app"
    hidden: false

ROLE_NAME_remove_login_items: []
EOF

sed -i '' "s/ROLE_NAME/$ROLE_NAME/g" "$REPO_ROOT/group_vars/$ROLE_NAME.yml"

# 5. Add to inventory.ini
echo "" >> "$REPO_ROOT/inventory.ini"
echo "[$ROLE_NAME]" >> "$REPO_ROOT/inventory.ini"
echo "${ROLE_NAME}_machine ansible_host=127.0.0.1 ansible_connection=local ansible_python_interpreter=/usr/local/bin/python3 machine_type=$ROLE_NAME" >> "$REPO_ROOT/inventory.ini"

# 6. Add to site.yml (before the existing roles)
# This is tricky - we'll just show instructions
echo ""
echo "✅ Role scaffolding complete!"
echo ""
echo "📝 Manual steps remaining:"
echo ""
echo "1. Edit site.yml and add this role:"
echo "   roles:"
echo "     - role: $ROLE_NAME"
echo "       when: machine_type == '$ROLE_NAME'"
echo "       tags: ['$ROLE_NAME', 'apps', 'config']"
echo ""
echo "2. Edit scripts/setup.sh and add menu option:"
echo "   In the menu section, add:"
echo "   echo \"X) $ROLE_DESC\""
echo ""
echo "   In the case statement, add:"
echo "   X)"
echo "       TARGET=\"$ROLE_NAME\""
echo "       DESC=\"$ROLE_DESC\""
echo "       ;;"
echo ""
echo "3. (Optional) Add app backups to vars/app_backups.yml:"
echo "   ${ROLE_NAME}_apps_to_backup:"
echo "     - app1"
echo "     - app2"
echo ""
echo "4. Customize group_vars/$ROLE_NAME.yml with your apps"
echo ""
echo "📂 Files created:"
echo "   - roles/$ROLE_NAME/tasks/main.yml"
echo "   - roles/$ROLE_NAME/handlers/main.yml"
echo "   - group_vars/$ROLE_NAME.yml"
echo "   - inventory.ini (updated)"
echo ""
echo "🧪 Test your new role:"
echo "   ansible-playbook site.yml -i inventory.ini --limit $ROLE_NAME --check"