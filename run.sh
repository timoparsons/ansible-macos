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
# Usage: inspect_backup <backup_dir> <role> [ssh]
# For app backups, pass the full app dir e.g. .../apps/terminal
# For dotfiles, pass parent dir — finds role-specific file e.g. dotfiles-studio-YYYYMMDD.tar.zst
# For ssh, pass parent dir — finds any .tar.zst (no role in filename)
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

  # SSH has no role in filename, dotfiles/apps do
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
      "Dry run full provision (--check)" \
      "Check playbook syntax" \
      "List available tags" \
      "List recent backups" \
      "Inspect app backup…" \
      "Inspect dotfiles backup" \
      "Inspect SSH backup" \
      "Mount network volume" \
      "Unmount network volume" \
      "Refresh repo from GitHub" \
      "── Back")

    case "$choice" in
      "Dry run full provision (--check)")
        run_cmd "ansible-playbook site.yml -i inventory.ini --limit $role --check"
        ;;
      "Check playbook syntax")
        run_cmd "ansible-playbook site.yml -i inventory.ini --syntax-check"
        ;;
      "List available tags")
        run_cmd "ansible-playbook site.yml -i inventory.ini --limit $role --list-tags"
        ;;
      "List recent backups")
        run_cmd "ls -lht $(active_mount)/macos/apps/ 2>/dev/null || echo 'Network volume not mounted'"
        ;;
      "Inspect app backup…")
        local app
        app=$(gum input --placeholder "app name  e.g. terminal" --prompt "> " --width 40)
        [[ -z "$app" ]] && continue
        inspect_backup "$(active_mount)/macos/apps/$app" "$role"
        ;;
      "Inspect dotfiles backup")
        inspect_backup "$(active_mount)/macos/dotfiles" "$role"
        ;;
      "Inspect SSH backup")
        inspect_backup "$(active_mount)/macos/ssh" "$role" "ssh"
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
  # Already mounted at /Volumes or ~/mnt
  if mount | grep -q "backup_proxmox"; then
    return 0
  fi
  # GUI session — let macOS handle it natively (uses keychain, no password prompt)
  if [[ -n "${SSH_CONNECTION:-}" ]]; then
    return 1  # SSH session — skip, user can mount manually
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

  # Change to repo root so relative paths in ansible commands work
  cd "$SCRIPT_DIR"

  # Resolve role from dotfile or first-run picker
  local role
  role=$(resolve_role)

  # Attempt to mount network volume in the background
  header >&2
  echo "" >&2
  gum style --foreground "$MUTED" "  Connecting to network volume…" >&2
  if mount_network_volume; then
    gum style --foreground "$PINK" "  ✓ Network volume mounted" >&2
  else
    gum style --foreground "196" "  ✗ Could not mount network volume — use Utilities → Mount if needed" >&2
  fi
  sleep 1

  # Main loop
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