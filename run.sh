#!/usr/bin/env bash
# =============================================================================
# run.sh — Interactive menu for mac-setup ansible playbooks
# Requires: gum (brew install gum)
# =============================================================================

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="$SCRIPT_DIR/inventory.ini"

# ── Colours / style ───────────────────────────────────────────────────────────
export GUM_CHOOSE_CURSOR_FOREGROUND="212"
export GUM_CHOOSE_SELECTED_FOREGROUND="212"
export GUM_CONFIRM_SELECTED_FOREGROUND="212"
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
detect_role() {
  local hostname
  hostname="$(hostname -s | tr '[:upper:]' '[:lower:]')"

  # Match hostname against inventory group names
  # inventory.ini groups: [studio], [laptop], [editor], [family]
  for role in studio laptop editor family; do
    if echo "$hostname" | grep -qi "$role"; then
      echo "$role"
      return
    fi
  done

  # Fallback: check if inventory has a host entry matching hostname
  if [[ -f "$INVENTORY" ]]; then
    for role in studio laptop editor family; do
      if grep -A5 "^\[$role\]" "$INVENTORY" | grep -qi "$hostname"; then
        echo "$role"
        return
      fi
    done
  fi

  echo ""
}

pick_role() {
  gum choose --header "Select machine role:" studio laptop editor family
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
      "Restore SSH keys" \
      "Restore dotfiles" \
      "Restore SSH from different machine…" \
      "Restore dotfiles from different machine…" \
      "Restore apps from different machine…" \
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
      "Restore SSH keys")
        run_cmd "ansible-playbook playbooks/restore-ssh.yml -i inventory.ini --limit $role"
        ;;
      "Restore dotfiles")
        run_cmd "ansible-playbook playbooks/restore-dotfiles.yml -i inventory.ini --limit $role"
        ;;
      "Restore SSH from different machine…")
        local from; from=$(prompt_machine)
        run_cmd "ansible-playbook playbooks/restore-ssh.yml -i inventory.ini --limit $role -e \"restore_from_machine=$from\""
        ;;
      "Restore dotfiles from different machine…")
        local from; from=$(prompt_machine)
        run_cmd "ansible-playbook playbooks/restore-dotfiles.yml -i inventory.ini --limit $role -e \"restore_from_machine=$from\""
        ;;
      "Restore apps from different machine…")
        local from; from=$(prompt_machine)
        run_cmd "ansible-playbook playbooks/restore-apps.yml -i inventory.ini --limit $role -e \"restore_from_machine=$from\""
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
        run_cmd "ls -lht /Volumes/backup_proxmox/macos/apps/ 2>/dev/null || echo 'Network volume not mounted'"
        ;;
      "── Back") break ;;
    esac
  done
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  check_deps

  # Change to repo root so relative paths in ansible commands work
  cd "$SCRIPT_DIR"

  # Detect or pick role
  local role
  role=$(detect_role)

  header
  echo ""

  if [[ -n "$role" ]]; then
    gum style --foreground "$MUTED" "  Detected role: $(gum style --foreground "$PINK" --bold "$role")"
    echo ""
    if ! gum confirm "Use '$role'?"; then
      role=$(pick_role)
    fi
  else
    gum style --foreground "$MUTED" "  Could not detect role from hostname."
    echo ""
    role=$(pick_role)
  fi

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
      "  Switch role") role=$(pick_role) ;;
      "  Quit") echo ""; exit 0 ;;
    esac
  done
}

main "$@"
