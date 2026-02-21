#!/bin/zsh
# =============================================================================
# resolve_restore.sh — Interactive DaVinci Resolve settings restore
# Requires: gum (brew install gum), zstd (brew install zstd), python3, rsync
# =============================================================================
#
# Usage:
#   ./resolve_restore.sh                          # auto-find archive
#   ./resolve_restore.sh /path/to/archive.tar.zst # explicit path
#
# Archive search order:
#   1. Explicit path argument
#   2. Most recent resolve-*.tar.zst on ~/Desktop
#   3. Most recent resolve-*.tar.zst on the backup_proxmox network volume
#      at macos/apps/resolve/ (mounts automatically if reachable)
#
# =============================================================================

setopt err_exit pipe_fail

SCRIPT_DIR="${0:A:h}"
CURRENT_USER="$(whoami)"
ARCHIVE=""
TEMP_DIR=""

# ── Network volume paths (mirrors run.sh) ─────────────────────────────────────
HOME_MOUNT="$HOME/mnt/backup_proxmox"
VOLUMES_MOUNT="/Volumes/backup_proxmox"
RESOLVE_SUBPATH="macos/apps/resolve"

# ── User preferences exclusions ───────────────────────────────────────────────
# Files and folders within the DaVinci Resolve preferences directory that will
# NOT be restored. Add to this list to block machine-specific or volatile state.
# Globs are supported (rsync --exclude syntax).
PREFS_EXCLUDE=(
  ".credentials"       # machine-specific auth tokens
  ".update"            # update state — machine-specific
)

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

# ── Cleanup ───────────────────────────────────────────────────────────────────
cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT INT TERM

# ── Dependency check ──────────────────────────────────────────────────────────
check_deps() {
  local missing=()
  for tool in gum zstd python3 rsync; do
    command -v "$tool" &>/dev/null || missing+=("$tool")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "✗ Missing required tools: ${missing[*]}" >&2
    echo "" >&2
    for t in $missing; do
      case "$t" in
        gum)     echo "  brew install gum"   >&2 ;;
        zstd)    echo "  brew install zstd"  >&2 ;;
        rsync)   echo "  brew install rsync" >&2 ;;
        python3) echo "  https://www.python.org/downloads/" >&2 ;;
      esac
    done
    exit 1
  fi
}

header() {
  clear
  gum style \
    --foreground "$PINK" --border-foreground "$PINK" --border double \
    --align center --width 52 --padding "0 2" \
    "DaVinci Resolve" "Settings Restore"
}

# ── Network volume helpers ────────────────────────────────────────────────────
active_mount() {
  if mount | grep -q "$VOLUMES_MOUNT"; then
    echo "$VOLUMES_MOUNT"
  elif mount | grep -q "$HOME_MOUNT"; then
    echo "$HOME_MOUNT"
  else
    echo ""
  fi
}

mount_network_volume() {
  # Already mounted?
  [[ -n "$(active_mount)" ]] && return 0

  # Can't show the macOS auth dialog over SSH
  [[ -n "${SSH_CONNECTION:-}" ]] && return 1

  # Try the macOS open trick (prompts for credentials in Finder)
  gum style --foreground "$MUTED" "  Connecting to network volume…"
  open "smb://10.1.1.10/backup_proxmox" 2>/dev/null || true
  local i=0
  while (( i < 10 )); do
    sleep 1
    if [[ -n "$(active_mount)" ]]; then
      gum style --foreground "$PINK" "  ✓ Network volume mounted"
      return 0
    fi
    (( i++ ))
  done

  # Auto-mount failed — offer a manual credential prompt
  echo ""
  gum style --foreground "214" "  ⚠  Could not auto-mount — try entering credentials manually."
  echo ""
  gum confirm "Enter SMB credentials to mount now?" || return 1

  local smb_user smb_pass
  smb_user=$(gum input --placeholder "username" --prompt "  User: " --width 40)
  [[ -z "$smb_user" ]] && return 1
  smb_pass=$(gum input --placeholder "password" --prompt "  Pass: " --width 40 --password)
  [[ -z "$smb_pass" ]] && return 1

  local smb_pass_encoded="${smb_pass//@/%40}"
  mkdir -p "$HOME_MOUNT"
  if mount_smbfs "//${smb_user}:${smb_pass_encoded}@10.1.1.10/backup_proxmox" "$HOME_MOUNT" 2>/dev/null; then
    gum style --foreground "$PINK" "  ✓ Mounted at $HOME_MOUNT"
    return 0
  else
    gum style --foreground "196" "  ✗ Mount failed — check credentials and network"
    rmdir "$HOME_MOUNT" 2>/dev/null || true
    return 1
  fi
}

# ── Archive discovery ─────────────────────────────────────────────────────────
find_archive() {
  # 1. Explicit argument
  if [[ -n "${1:-}" ]]; then
    [[ ! -f "$1" ]] && { gum style --foreground "196" "✗ Archive not found: $1"; exit 1; }
    ARCHIVE="$1"
    gum style --foreground "$MUTED" "  Source : explicit path"
    return
  fi

  # 2. Desktop — zsh nullglob (N) avoids errors when no files match
  local -a desktop_matches
  desktop_matches=($HOME/Desktop/resolve-*.tar.zst(NOn))
  if [[ ${#desktop_matches} -gt 0 ]]; then
    ARCHIVE="$desktop_matches[1]"
    gum style --foreground "$MUTED" "  Source : Desktop"
    return
  fi

  gum style --foreground "$MUTED" "  No archive found on Desktop — checking network volume…"
  echo ""

  # 3. Network volume
  if mount_network_volume; then
    local mount_base="$(active_mount)"
    local net_dir="${mount_base}/${RESOLVE_SUBPATH}"
    local -a net_matches
    net_matches=($net_dir/resolve-*.tar.zst(NOn))
    if [[ ${#net_matches} -gt 0 ]]; then
      ARCHIVE="$net_matches[1]"
      gum style --foreground "$MUTED" "  Source : network volume"
      return
    else
      gum style --foreground "196" "  ✗ No resolve-*.tar.zst found in ${net_dir}"
    fi
  else
    gum style --foreground "$MUTED" "  Network volume not available."
  fi

  echo ""
  gum style --foreground "196" "✗ No archive found."
  gum style --foreground "$MUTED" \
    "  Place a resolve-*.tar.zst on your Desktop, mount the network volume,"
  gum style --foreground "$MUTED" \
    "  or pass the path explicitly:  ./resolve_restore.sh /path/to/archive.tar.zst"
  exit 1
}

# ── Category mapping ──────────────────────────────────────────────────────────
get_category() {
  local dest="$1"
  case "$dest" in
    resolve/preferences/*/usersmartfolder*)        echo "smart_bins" ;;
    resolve/preferences/*/usersmartfilter*)        echo "smart_filters" ;;
    resolve/preferences/*/keyboard*)               echo "keyboard_presets" ;;
    resolve/preferences/*/mediametadata*)          echo "media_metadata" ;;
    resolve/preferences/*)                         echo "user_prefs" ;;
    resolve/lut*)                                  echo "luts" ;;
    resolve/resolve-settings*)                     echo "shared_settings" ;;
    resolve/application-support/Fusion/Templates*) echo "fusion_templates" ;;
    resolve/application-support/Fusion/Scripts*)   echo "fusion_scripts" ;;
    resolve/application-support/Fusion*)           echo "fusion_user" ;;
    resolve/application-support/Scripts*)          echo "resolve_scripts" ;;
    resolve/system-fusion*)                        echo "fusion_system" ;;
    resolve/workflow-plugins*)                     echo "fusion_system" ;;
    resolve/ofx-plugins*)                          echo "fx" ;;
    resolve/vst*)                                  echo "vst_plugins" ;;
    resolve/components*)                           echo "vst_plugins" ;;
    resolve/fx*)                                   echo "fx" ;;
    *)                                             echo "user_prefs" ;;
  esac
}

typeset -a CATEGORY_KEYS=(
  user_prefs
  keyboard_presets
  smart_bins
  smart_filters
  media_metadata
  shared_settings
  fusion_templates
  fusion_scripts
  fusion_user
  fusion_system
  resolve_scripts
  luts
  fx
  vst_plugins
)

typeset -A CATEGORY_LABELS=(
  [user_prefs]="User Preferences (.plist + prefs folder)"
  [keyboard_presets]="Keyboard Presets"
  [smart_bins]="Smart Bins"
  [smart_filters]="Smart Filters"
  [media_metadata]="Media Metadata Presets"
  [shared_settings]="Shared Folder Settings (/Users/Shared/Resolve)"
  [luts]="LUTs"
  [fx]="FX + OFX Plugins"
  [fusion_templates]="Fusion Templates (user)"
  [fusion_scripts]="Fusion Scripts (user)"
  [fusion_user]="Fusion — all user data"
  [fusion_system]="Fusion Scripts — system-wide"
  [resolve_scripts]="Resolve Scripts (user)"
  [vst_plugins]="VST / Audio Component Plugins"
)

typeset -A CAT_PATHS    # key → newline-delimited "src|dest|sudo|is_file" entries
typeset -A CAT_PRESENT  # key → "1"

typeset MANIFEST_APP MANIFEST_DATE MANIFEST_MACHINE

# ── Stream manifest.json from archive and populate category maps ───────────────
load_manifest() {
  local manifest_json
  manifest_json=$(mktemp /tmp/resolve_manifest.XXXXXX.json)

  gum spin --title "Reading manifest…" --spinner dot -- \
    zsh -c "zstd -d -c ${(q)ARCHIVE} | tar -xf - -O manifest.json 2>/dev/null > ${(q)manifest_json}" || {
      gum style --foreground "196" "✗ Could not read manifest.json from archive."
      rm -f "$manifest_json"
      exit 1
    }

  local raw
  raw=$(python3 - "$manifest_json" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    m = json.load(f)

print(f"MANIFEST_APP={m.get('app_key','resolve')}")
print(f"MANIFEST_DATE={m.get('backup_date','unknown')}")
print(f"MANIFEST_MACHINE={m.get('machine_type','unknown')}")
print("---")

for p in m.get('paths', []):
    src     = p.get('src', '')
    dest    = p.get('dest', '')
    sudo_   = '1' if p.get('needs_sudo', False) else '0'
    is_file = '1' if p.get('is_file', False)    else '0'
    print(f"{src}|{dest}|{sudo_}|{is_file}")
PYEOF
  )
  rm -f "$manifest_json"

  local in_paths=false line _src _dest _sudo _isfile _cat
  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      in_paths=true
      continue
    fi
    if ! $in_paths; then
      case "$line" in
        MANIFEST_APP=*)     MANIFEST_APP="${line#MANIFEST_APP=}" ;;
        MANIFEST_DATE=*)    MANIFEST_DATE="${line#MANIFEST_DATE=}" ;;
        MANIFEST_MACHINE=*) MANIFEST_MACHINE="${line#MANIFEST_MACHINE=}" ;;
      esac
    else
      [[ -z "$line" ]] && continue
      IFS='|' read -r _src _dest _sudo _isfile <<< "$line"
      [[ -z "$_src" ]] && continue
      _cat=$(get_category "$_dest")
      CAT_PATHS[$_cat]+="${_src}|${_dest}|${_sudo}|${_isfile}"$'\n'
      CAT_PRESENT[$_cat]=1
    fi
  done <<< "$raw"
}

# ── Extraction ──────────────────────────────────────────────────────────────────────────────
# BSD tar (macOS) does not reliably support wildcard path filtering, so we
# extract the full archive into a temp dir and let restore_entry copy only the
# paths belonging to the selected categories.
extract_selected() {
  TEMP_DIR=$(mktemp -d /tmp/resolve_restore.XXXXXX)

  gum spin --title "Extracting archive…" --spinner dot -- \
    zsh -c "zstd -d -c ${(q)ARCHIVE} | tar -xf - -C ${(q)TEMP_DIR}" \
    2>/dev/null || true
}

# ── Restore a single entry ────────────────────────────────────────────────────
restore_entry() {
  local src="$1" dest="$2" needs_sudo="$3" is_file="$4"

  local dest_abs
  if [[ "$src" == "~/"* ]]; then
    dest_abs="${HOME}/${src#\~/}"
  elif [[ "$src" == "~" ]]; then
    dest_abs="$HOME"
  else
    dest_abs="$src"
  fi

  local source_path="${TEMP_DIR}/${dest}"

  if [[ ! -e "$source_path" ]]; then
    gum style --foreground "$MUTED" "    ⚠  not in archive: $dest"
    return 0
  fi

  local parent_dir="${dest_abs:h}"

  if [[ "$needs_sudo" == "1" ]]; then
    sudo mkdir -p "$parent_dir"
  else
    mkdir -p "$parent_dir"
  fi

  if [[ "$is_file" == "1" ]]; then
    if [[ "$needs_sudo" == "1" ]]; then
      sudo cp -f "$source_path" "$dest_abs"
    else
      cp -f "$source_path" "$dest_abs"
    fi
  else
    # Build rsync exclude flags — applied only when restoring the prefs directory
    local -a excl_flags=()
    if [[ "$dest" == "resolve/preferences/DaVinci Resolve" ]]; then
      for pat in $PREFS_EXCLUDE; do
        excl_flags+=(--exclude="$pat")
      done
    fi
    if [[ "$needs_sudo" == "1" ]]; then
      sudo mkdir -p "$dest_abs"
      sudo rsync -a --no-owner --no-group $excl_flags "$source_path/" "$dest_abs/"
    else
      mkdir -p "$dest_abs"
      rsync -a --no-owner --no-group $excl_flags "$source_path/" "$dest_abs/"
    fi
  fi
}

# ── Restore one category ──────────────────────────────────────────────────────
restore_category() {
  local key="$1"
  local label="${CATEGORY_LABELS[$key]}"
  local paths="${CAT_PATHS[$key]:-}"
  local ok=0 fail=0

  if [[ -z "$paths" ]]; then
    gum style --foreground "$MUTED" "  ⚠  $label — no paths found"
    return 0
  fi

  while IFS='|' read -r src dest sudo_ is_file; do
    [[ -z "$src" ]] && continue
    if restore_entry "$src" "$dest" "$sudo_" "$is_file" 2>/dev/null; then
      (( ok++ ))
    else
      (( fail++ ))
      gum style --foreground "196" "  ✗ Failed: $dest"
    fi
  done <<< "$paths"

  if (( fail == 0 )); then
    gum style --foreground "$PINK" \
      "  ✓ $label $(gum style --foreground "$MUTED" "(${ok} item(s))")"
  else
    gum style --foreground "214" \
      "  ⚠  $label $(gum style --foreground "$MUTED" "(${ok} ok, ${fail} failed)")"
  fi
}

# ── Check if a selection needs sudo ──────────────────────────────────────────
selection_needs_sudo() {
  local keys=("$@")
  for key in $keys; do
    local paths="${CAT_PATHS[$key]:-}"
    if echo "$paths" | awk -F'|' '$3=="1"{found=1} END{exit !found}' 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

# ── Selection → confirm → extract → restore ───────────────────────────────────
run_selection_menu() {
  local available_keys=()
  for key in $CATEGORY_KEYS; do
    [[ -n "${CAT_PRESENT[$key]:-}" ]] && available_keys+=("$key")
  done

  if [[ ${#available_keys[@]} -eq 0 ]]; then
    gum style --foreground "196" "  ✗ No Resolve settings found in this archive."
    echo ""
    exit 1
  fi

  local display_items=()
  for key in $available_keys; do
    display_items+=("${CATEGORY_LABELS[$key]}")
  done

  echo ""
  gum style --foreground "$MUTED" \
    "  Space to select · Enter to confirm · Ctrl-A to select all"
  echo ""

  local chosen
  chosen=$(gum choose --no-limit \
    --header "Select settings to restore:" \
    $display_items) || true

  [[ -z "$chosen" ]] && {
    gum style --foreground "$MUTED" "Nothing selected. Cancelled."
    exit 0
  }

  # Map chosen display labels back to category keys
  local selected_keys=()
  while IFS= read -r label; do
    for key in $available_keys; do
      if [[ "${CATEGORY_LABELS[$key]}" == "$label" ]]; then
        selected_keys+=("$key")
        break
      fi
    done
  done <<< "$chosen"

  [[ ${#selected_keys[@]} -eq 0 ]] && {
    gum style --foreground "196" "No valid selections."
    exit 1
  }

  # ── Confirmation summary ───────────────────────────────────────────────────
  echo ""
  gum style --foreground "$PINK" --bold "  Ready to restore:"
  echo ""
  for key in $selected_keys; do
    gum style --foreground "$MUTED" "     • ${CATEGORY_LABELS[$key]}"
  done

  if selection_needs_sudo $selected_keys; then
    echo ""
    gum style --foreground "214" \
      "  ⚠  Some items write to system paths — you will be prompted for sudo."
  fi

  # ── Warn if Resolve is currently open ─────────────────────────────────────
  if pgrep -xq "DaVinci Resolve" 2>/dev/null; then
    echo ""
    gum style --foreground "214" "  ⚠  DaVinci Resolve is currently running."
    echo ""
    if gum confirm "Quit DaVinci Resolve now and continue?"; then
      osascript -e 'quit app "DaVinci Resolve"' 2>/dev/null \
        || killall "DaVinci Resolve" 2>/dev/null || true
      sleep 2
    else
      gum style --foreground "$MUTED" "Cancelled."
      exit 0
    fi
  fi

  echo ""
  gum confirm "Proceed with restore?" \
    || { gum style --foreground "$MUTED" "Cancelled."; exit 0; }

  # ── Selective extraction — only pull the chosen paths from the archive ─────
  echo ""
  extract_selected $selected_keys

  # ── Restore ───────────────────────────────────────────────────────────────
  echo ""
  gum style --foreground "$PINK" --bold "  Restoring…"
  echo ""
  for key in $selected_keys; do
    restore_category "$key"
  done

  # Flush preference daemon so macOS picks up restored plists immediately
  killall -u "$CURRENT_USER" cfprefsd 2>/dev/null || true

  echo ""
  gum style --foreground "$PINK" \
    "  ✓ Restore complete — launch DaVinci Resolve to verify."
  echo ""
  gum input --placeholder "Press enter to exit…" > /dev/null || true
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  check_deps
  header
  echo ""

  find_archive "${1:-}"

  echo ""
  gum style --foreground "$MUTED" "  Archive : ${ARCHIVE:t}"
  echo ""

  load_manifest

  gum style --foreground "$MUTED" \
    "  Backed up : ${MANIFEST_DATE:-unknown}  ·  Source machine: ${MANIFEST_MACHINE:-unknown}"
  gum style --foreground "$MUTED" \
    "  Restoring as      : ${CURRENT_USER}"

  run_selection_menu
}

main "$@"