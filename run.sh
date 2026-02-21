#!/usr/bin/env bash
# =============================================================================
# run.sh — Interactive menu for mac-setup ansible playbooks
# Requires: gum (brew install gum)
# =============================================================================

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_MOUNT="$HOME/mnt/backup_proxmox"
VOLUMES_MOUNT="/Volumes/backup_proxmox"

# Returns the active mount base path, preferring /Volumes then ~/mnt
active_mount() {
  if mount | grep -q "$VOLUMES_MOUNT"; then
    echo "$VOLUMES_MOUNT"
  elif mount | grep -q "$HOME_MOUNT"; then
    echo "$HOME_MOUNT"
  else
    echo "$VOLUMES_MOUNT"  # default, will fail gracefully if not mounted
  fi
}

# ── Cleanup on exit ───────────────────────────────────────────────────────────
cleanup() {
  if mount | grep -q "$HOME_MOUNT"; then
    diskutil unmount "$HOME_MOUNT" 2>/dev/null       || umount "$HOME_MOUNT" 2>/dev/null       || true
  fi
  rmdir "$HOME_MOUNT" 2>/dev/null || true
  rmdir "$HOME/mnt" 2>/dev/null || true
}
trap cleanup EXIT

# ── Colours / style ───────────────────────────────────────────────────────────
export GUM_CHOOSE_CURSOR_FOREGROUND="212"
export GUM_CHOOSE_SELECTED_FOREGROUND="0"
export GUM_CHOOSE_SELECTED_BACKGROUND="212"
export GUM_CONFIRM_SELECTED_FOREGROUND="0"
export GUM_CONFIRM_SELECTED_BACKGROUND="212"
export GUM_INPUT_CURSOR_FOREGROUND="212"
export GUM_SPIN_SPINNER_FOREGROUND="212"

PINK="212"
MUTED="240"
BOLD="\033[1m"
RESET="\033[0m"

# ── Helpers ───────────────────────────────────────────────────────────────────
check_deps() {
  if ! command -v gum &>/dev/null; then
    echo "✗ gum is not installed. Run: brew install gum" >&2
    exit 1
  fi
  if ! command -v ansible-playbook &>/dev/null; then
    echo "✗ ansible-playbook is not installed." >&2
    exit 1
  fi
}

header() {
  clear
  gum style \
    --foreground "$PINK" --border-foreground "$PINK" --border double \
    --align center --width 52 --padding "0 2" \
    "mac-setup" "Ansible Playbook Runner"
}

run_cmd() {
  # Shows the command, asks to confirm, then streams output
  local cmd="$*"
  echo ""
  gum style --foreground "$MUTED" "$ $cmd"
  echo ""
  gum confirm "Run this command?" || { gum style --foreground "$MUTED" "Cancelled."; return; }
  echo ""
  eval "$cmd"
  echo ""
  gum style --foreground "$PINK" "✓ Done"
  echo ""
  gum input --placeholder "Press enter to return to menu…" > /dev/null || true
}

prompt_apps() {
  gum input \
    --placeholder "app names, comma-separated  e.g. raycast,vscode,resolve" \
    --prompt "> " \
    --width 60
}

prompt_machine() {
  gum choose --header "Restore FROM which machine?" studio laptop editor family
}

# ── Role detection ─────────────────────────────────────────────────────────────
ROLE_FILE="$HOME/.mac-setup-role"

read_role() {
  if [[ -f "$ROLE_FILE" ]]; then
    cat "$ROLE_FILE"
  else
    echo ""
  fi
}

save_role() {
  local role="$1"
  echo "$role" > "$ROLE_FILE"
  gum style --foreground "$MUTED" "  Saved to $ROLE_FILE"
}

pick_role() {
  gum choose --header "Select machine role:" studio laptop editor family
}

resolve_role() {
  local role
  role=$(read_role)

  header >&2
  echo "" >&2

  if [[ -n "$role" ]]; then
    gum style --foreground "$MUTED" "  Role: $(gum style --foreground "$PINK" --bold "$role")  $(gum style --foreground "$MUTED" "(from ~/.mac-setup-role)")" >&2
    echo "" >&2
  else
    gum style --foreground "$MUTED" "  No role set yet for this user." >&2
    echo "" >&2
    role=$(pick_role)
    save_role "$role" >&2
  fi

  echo "$role"
}

# ── Inspect backup helper ─────────────────────────────────────────────────────
inspect_backup() {
  local backup_dir="$1"
  local role="$2"
  local mode="${3:-}"

  if [[ ! -d "$backup_dir" ]]; then
    echo ""
    gum style --foreground "196" "  ✗ No backup folder found: $backup_dir"
    echo ""
    gum input --placeholder "Press enter to continue…" > /dev/null || true
    return
  fi

  local latest
  if [[ "$mode" == "ssh" ]]; then
    latest=$(ls -t "$backup_dir"/*.tar.zst 2>/dev/null | head -1)
  else
    latest=$(ls -t "$backup_dir"/*-"$role"-*.tar.zst 2>/dev/null | head -1)
  fi

  if [[ -z "$latest" ]]; then
    echo ""
    gum style --foreground "196" "  ✗ No .tar.zst files found in $backup_dir"
    echo ""
    gum input --placeholder "Press enter to continue…" > /dev/null || true
    return
  fi

  echo ""
  gum style --foreground "$MUTED" "  Most recent: $(basename "$latest")"
  echo ""
  gum confirm "List contents?" || return
  echo ""
  zstd -d -c "$latest" | tar -tf - | sort
  echo ""
  gum style --foreground "$PINK" "✓ Done"
  echo ""
  gum input --placeholder "Press enter to return to menu…" > /dev/null || true
}

# ── Missing apps checker ──────────────────────────────────────────────────────
list_missing_apps() {
  local role="$1"
  local group_vars="$SCRIPT_DIR/group_vars/$role.yml"

  header
  gum style --foreground "$PINK" --bold "  MISSING APPS  · $role"
  echo ""

  if [[ ! -f "$group_vars" ]]; then
    gum style --foreground "196" "  ✗ No group_vars file found: $group_vars"
    echo ""
    gum input --placeholder "Press enter to continue…" > /dev/null || true
    return
  fi

  # ── Brew formulae ──────────────────────────────────────────────────────────
  gum style --bold "📦  Formulae"
  local installed_formulae
  installed_formulae=$(brew list --formula 2>/dev/null)

  local formula_missing=()
  local in_formula_block=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^${role}_formula_apps: ]]; then
      in_formula_block=true
      continue
    fi
    # Stop at next top-level key (not indented)
    if $in_formula_block && [[ "$line" =~ ^[a-zA-Z_] ]]; then
      in_formula_block=false
    fi
    if $in_formula_block && [[ "$line" =~ ^[[:space:]]*-[[:space:]]+([^#]+) ]]; then
      local pkg="${BASH_REMATCH[1]}"
      pkg="${pkg%%#*}"       # strip inline comments
      pkg="${pkg// /}"       # strip spaces
      if [[ -n "$pkg" ]] && ! echo "$installed_formulae" | grep -qx "$pkg"; then
        formula_missing+=("$pkg")
      fi
    fi
  done < "$group_vars"

  if [[ ${#formula_missing[@]} -eq 0 ]]; then
    gum style --foreground "$PINK" "  ✓ all installed"
  else
    for pkg in "${formula_missing[@]}"; do
      gum style --foreground "196" "  ✗  $pkg"
    done
  fi
  echo ""

  # ── Brew casks ─────────────────────────────────────────────────────────────
  gum style --bold "🖥   Casks"
  local installed_casks
  installed_casks=$(brew list --cask 2>/dev/null)

  local cask_missing=()
  local in_cask_block=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^${role}_cask_apps: ]]; then
      in_cask_block=true
      continue
    fi
    if $in_cask_block && [[ "$line" =~ ^[a-zA-Z_] ]]; then
      in_cask_block=false
    fi
    if $in_cask_block && [[ "$line" =~ ^[[:space:]]*-[[:space:]]+([^#]+) ]]; then
      local pkg="${BASH_REMATCH[1]}"
      pkg="${pkg%%#*}"
      pkg="${pkg// /}"
      if [[ -n "$pkg" ]] && ! echo "$installed_casks" | grep -qx "$pkg"; then
        cask_missing+=("$pkg")
      fi
    fi
  done < "$group_vars"

  if [[ ${#cask_missing[@]} -eq 0 ]]; then
    gum style --foreground "$PINK" "  ✓ all installed"
  else
    for pkg in "${cask_missing[@]}"; do
      gum style --foreground "196" "  ✗  $pkg"
    done
  fi
  echo ""

  # ── MAS apps ───────────────────────────────────────────────────────────────
  gum style --bold "🍎  Mac App Store"
  local installed_mas
  installed_mas=$(mas list 2>/dev/null | awk '{print $1}')

  local mas_missing=()
  local in_mas_block=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^${role}_mas_apps: ]]; then
      in_mas_block=true
      continue
    fi
    if $in_mas_block && [[ "$line" =~ ^[a-zA-Z_] ]]; then
      in_mas_block=false
    fi
    if $in_mas_block && [[ "$line" =~ id:[[:space:]]*([0-9]+) ]]; then
      local mas_id="${BASH_REMATCH[1]}"
      local mas_name
      mas_name=$(echo "$line" | sed "s/.*name:[[:space:]]*['\"]//;s/['\"].*//")
      if [[ -n "$mas_id" ]] && ! echo "$installed_mas" | grep -qx "$mas_id"; then
        mas_missing+=("$mas_name ($mas_id)")
      fi
    fi
  done < "$group_vars"

  if [[ ${#mas_missing[@]} -eq 0 ]]; then
    gum style --foreground "$PINK" "  ✓ all installed"
  else
    for entry in "${mas_missing[@]}"; do
      gum style --foreground "196" "  ✗  $entry"
    done
  fi
  echo ""

  # ── DMG/PKG apps ───────────────────────────────────────────────────────────
  gum style --bold "💿  DMG / PKG"

  local dmg_missing=()
  local in_dmg_block=false
  local current_name=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^${role}_dmg_pkg_apps: ]]; then
      in_dmg_block=true
      continue
    fi
    if $in_dmg_block && [[ "$line" =~ ^[a-zA-Z_] ]]; then
      in_dmg_block=false
    fi
    if $in_dmg_block; then
      # Capture name field (handles both "- name:" and "  name:" styles)
      if [[ "$line" =~ name:[[:space:]]*\"([^\"]+)\" ]] || [[ "$line" =~ name:[[:space:]]*\'([^\']+)\' ]] || [[ "$line" =~ name:[[:space:]]*([^#\r\n]+) ]]; then
        current_name="${BASH_REMATCH[1]}"
        current_name="${current_name%%#*}"
        current_name="${current_name%"${current_name##*[^[:space:]]}"}"  # trim trailing whitespace
        if [[ -n "$current_name" ]] && [[ ! -d "/Applications/${current_name}.app" ]]; then
          dmg_missing+=("$current_name")
        fi
      fi
    fi
  done < "$group_vars"

  if [[ ${#dmg_missing[@]} -eq 0 ]]; then
    gum style --foreground "$PINK" "  ✓ all installed"
  else
    for app in "${dmg_missing[@]}"; do
      gum style --foreground "196" "  ✗  $app"
    done
  fi
  echo ""

  gum input --placeholder "Press enter to return to menu…" > /dev/null || true
}

# ── Submenus ──────────────────────────────────────────────────────────────────
menu_backup() {
  local role="$1"
  while true; do
    header
    gum style --foreground "$PINK" --bold "  BACKUP  · $role"
    echo ""
    local choice
    choice=$(gum choose \
      "Backup everything" \
      "Backup specific apps…" \
      "Backup SSH keys" \
      "Backup dotfiles" \
      "Backup login items" \
      "── Back")

    case "$choice" in
      "Backup everything")
        run_cmd "ansible-playbook playbooks/backup-full.yml -i inventory.ini --limit $role"
        ;;
      "Backup specific apps…")
        local apps; apps=$(prompt_apps)
        [[ -z "$apps" ]] && continue
        run_cmd "ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit $role -e \"apps_list=$apps\""
        ;;
      "Backup SSH keys")
        run_cmd "ansible-playbook playbooks/backup-ssh.yml -i inventory.ini --limit $role"
        ;;
      "Backup dotfiles")
        run_cmd "ansible-playbook playbooks/backup-dotfiles.yml -i inventory.ini --limit $role"
        ;;
      "Backup login items")
        run_cmd "ansible-playbook playbooks/backup-login-items.yml -i inventory.ini --limit $role"
        ;;
      "── Back") break ;;
    esac
  done
}

menu_restore() {
  local role="$1"
  while true; do
    header
    gum style --foreground "$PINK" --bold "  RESTORE  · $role"
    echo ""
    local choice
    choice=$(gum choose \
      "Restore everything" \
      "Restore specific apps…" \
      "Restore specific apps from another machine…" \
      "Restore SSH keys" \
      "Restore dotfiles" \
      "── Back")

    case "$choice" in
      "Restore everything")
        run_cmd "ansible-playbook playbooks/restore-ssh.yml -i inventory.ini --limit $role && \
ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit $role && \
ansible-playbook playbooks/restore-dotfiles.yml -i inventory.ini --limit $role"
        ;;
      "Restore specific apps…")
        local apps; apps=$(prompt_apps)
        [[ -z "$apps" ]] && continue
        run_cmd "ansible-playbook playbooks/selective/restore-apps-selective.yml -i inventory.ini --limit $role -e \"apps_list=$apps\""
        ;;
      "Restore specific apps from another machine…")
        local apps; apps=$(prompt_apps)
        [[ -z "$apps" ]] && continue
        local from; from=$(prompt_machine)
        run_cmd "ansible-playbook playbooks/selective/restore-apps-selective.yml -i inventory.ini --limit $role -e \"apps_list=$apps\" -e \"restore_from_machine=$from\""
        ;;
      "Restore SSH keys")
        run_cmd "ansible-playbook playbooks/restore-ssh.yml -i inventory.ini --limit $role"
        ;;
      "Restore dotfiles")
        run_cmd "ansible-playbook playbooks/restore-dotfiles.yml -i inventory.ini --limit $role"
        ;;
      "── Back") break ;;
    esac
  done
}

menu_provision() {
  local role="$1"
  while true; do
    header
    gum style --foreground "$PINK" --bold "  PROVISION  · $role"
    echo ""
    local choice
    choice=$(gum choose \
      "Full provision (apps + config)" \
      "Apps only" \
      "Config only (macOS settings)" \
      "Dotfiles only" \
      "SSH keys only" \
      "Dock configuration only" \
      "Install specific apps…" \
      "Install + restore specific apps…" \
      "── Back")

    case "$choice" in
      "Full provision (apps + config)")
        run_cmd "ansible-playbook site.yml -i inventory.ini --limit $role -K"
        ;;
      "Apps only")
        run_cmd "ansible-playbook site.yml -i inventory.ini --limit $role --tags apps"
        ;;
      "Config only (macOS settings)")
        run_cmd "ansible-playbook site.yml -i inventory.ini --limit $role --tags config"
        ;;
      "Dotfiles only")
        run_cmd "ansible-playbook site.yml -i inventory.ini --limit $role --tags dotfiles"
        ;;
      "SSH keys only")
        run_cmd "ansible-playbook site.yml -i inventory.ini --limit $role --tags ssh"
        ;;
      "Dock configuration only")
        run_cmd "ansible-playbook site.yml -i inventory.ini --limit $role --tags dock"
        ;;
      "Install specific apps…")
        local apps; apps=$(prompt_apps)
        [[ -z "$apps" ]] && continue
        run_cmd "ansible-playbook playbooks/selective/install-app-selective.yml -i inventory.ini --limit $role -e \"apps_list=$apps\""
        ;;
      "Install + restore specific apps…")
        local apps; apps=$(prompt_apps)
        [[ -z "$apps" ]] && continue
        run_cmd "ansible-playbook playbooks/selective/install-app-selective.yml -i inventory.ini --limit $role -e \"apps_list=$apps\" && \
ansible-playbook playbooks/selective/restore-apps-selective.yml -i inventory.ini --limit $role -e \"apps_list=$apps\""
        ;;
      "── Back") break ;;
    esac
  done
}

menu_utilities() {
  local role="$1"
  while true; do
    header
    gum style --foreground "$PINK" --bold "  UTILITIES  · $role"
    echo ""
    local choice
    choice=$(gum choose \
      "List missing apps" \
      "Dry run full provision (--check)" \
      "List available tags" \
      "Inspect backup…" \
      "Mount network volume" \
      "Unmount network volume" \
      "Refresh repo from GitHub" \
      "── Back")

    case "$choice" in
      "List missing apps")
        list_missing_apps "$role"
        ;;
      "Dry run full provision (--check)")
        run_cmd "ansible-playbook site.yml -i inventory.ini --limit $role --check"
        ;;
      "List available tags")
        run_cmd "ansible-playbook site.yml -i inventory.ini --limit $role --list-tags"
        ;;
      "Inspect backup…")
        local app
        app=$(gum input --placeholder "app name, or: dotfiles, ssh" --prompt "> " --width 40)
        [[ -z "$app" ]] && continue
        case "$app" in
          dotfiles) inspect_backup "$(active_mount)/macos/dotfiles" "$role" ;;
          ssh)      inspect_backup "$(active_mount)/macos/ssh" "$role" "ssh" ;;
          *)        inspect_backup "$(active_mount)/macos/apps/$app" "$role" ;;
        esac
        ;;
      "Mount network volume")
        echo ""
        if mount | grep -q "backup_proxmox"; then
          gum style --foreground "$PINK" "  ✓ Volume already mounted"
          echo ""
          gum input --placeholder "Press enter to return to menu…" > /dev/null || true
          continue
        fi
        local smb_user smb_pass
        smb_user=$(gum input --placeholder "username" --prompt "  User: " --width 40)
        [[ -z "$smb_user" ]] && continue
        smb_pass=$(gum input --placeholder "password" --prompt "  Pass: " --width 40 --password)
        [[ -z "$smb_pass" ]] && continue
        echo ""
        gum style --foreground "$MUTED" "  Mounting…"
        local smb_pass_encoded="${smb_pass//@/%40}"
        local actual_mount="$HOME/mnt/backup_proxmox"
        mkdir -p "$actual_mount"
        if mount_smbfs "//${smb_user}:${smb_pass_encoded}@10.1.1.10/backup_proxmox" "$actual_mount"; then
          gum style --foreground "$PINK" "  ✓ Mounted at $actual_mount"
        else
          gum style --foreground "196" "  ✗ Mount failed — check credentials and network"
          rmdir "$actual_mount" 2>/dev/null || true
        fi
        echo ""
        gum input --placeholder "Press enter to return to menu…" > /dev/null || true
        ;;
      "Unmount network volume")
        echo ""
        if ! mount | grep -q "backup_proxmox"; then
          gum style --foreground "$MUTED" "  Volume is not currently mounted."
          echo ""
          gum input --placeholder "Press enter to return to menu…" > /dev/null || true
          continue
        fi
        gum confirm "Unmount backup_proxmox?" || continue
        echo ""
        cleanup
        if ! mount | grep -q "backup_proxmox"; then
          gum style --foreground "$PINK" "  ✓ Unmounted and cleaned up"
        else
          gum style --foreground "196" "  ✗ Unmount failed — try: diskutil unmount force $HOME_MOUNT"
        fi
        echo ""
        gum input --placeholder "Press enter to return to menu…" > /dev/null || true
        ;;
      "Refresh repo from GitHub")
        echo ""
        gum style --foreground "196" "  ⚠  This will discard all local changes and reset to origin/main."
        echo ""
        gum confirm "Are you sure?" || { gum style --foreground "$MUTED" "Cancelled."; sleep 1; continue; }
        echo ""
        git -C "$SCRIPT_DIR" fetch --all && git -C "$SCRIPT_DIR" reset --hard origin/main
        echo ""
        gum style --foreground "$PINK" "✓ Repo updated"
        gum style --foreground "$MUTED" "  Exiting — restart run.sh to pick up changes"
        echo ""
        exit 0
        ;;
      "── Back") break ;;
    esac
  done
}

# ── Auto-mount network volume ─────────────────────────────────────────────────
mount_network_volume() {
  if mount | grep -q "backup_proxmox"; then
    return 0
  fi
  if [[ -n "${SSH_CONNECTION:-}" ]]; then
    return 1
  fi
  open "smb://10.1.1.10/backup_proxmox" 2>/dev/null
  local i=0
  while [[ $i -lt 10 ]]; do
    sleep 1
    mount | grep -q "backup_proxmox" && return 0
    (( i++ ))
  done
  return 1
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  check_deps

  cd "$SCRIPT_DIR"

  local role
  role=$(resolve_role)

  header >&2
  echo "" >&2
  gum style --foreground "$MUTED" "  Connecting to network volume…" >&2
  if mount_network_volume; then
    gum style --foreground "$PINK" "  ✓ Network volume mounted" >&2
  else
    gum style --foreground "196" "  ✗ Could not mount network volume — use Utilities → Mount if needed" >&2
  fi
  sleep 1

  while true; do
    header
    gum style --foreground "$PINK" --bold "  $role"
    echo ""
    local section
    section=$(gum choose \
      "  Backup" \
      "  Restore" \
      "  Provision" \
      "  Utilities" \
      "  Switch role" \
      "  Quit")

    case "$section" in
      "  Backup")    menu_backup "$role" ;;
      "  Restore")   menu_restore "$role" ;;
      "  Provision") menu_provision "$role" ;;
      "  Utilities") menu_utilities "$role" ;;
      "  Switch role") role=$(pick_role); save_role "$role" ;;
      "  Quit") echo ""; exit 0 ;;
    esac
  done
}

main "$@"