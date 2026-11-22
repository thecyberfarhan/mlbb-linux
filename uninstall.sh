#!/usr/bin/env bash
# mlbb-linux uninstaller. Removes ONLY what the installer created, tracked in the
# install manifest (~/.local/state/mlbb/install-manifest). It never touches files
# you already had, general tools (Waydroid, the ARM translator), or your Google
# account, and it tolerates files you deleted by hand: a missing item is skipped,
# never a hard error.
#
#   ./uninstall.sh          remove mlbb-linux's own files + KWin rules/script
#   ./uninstall.sh --all     also remove the config dir, the system files
#                            (udev rule, Docker drop-in) and the scrcpy-mask copy
set -uo pipefail

ALL=0; [ "${1:-}" = "--all" ] && ALL=1
STATE="$HOME/.local/state/mlbb"
MANIFEST="$STATE/install-manifest"

if [ -t 1 ]; then C_B=$'\033[1m'; C_G=$'\033[1;32m'; C_Y=$'\033[1;33m'; C_0=$'\033[0m'; else C_B=; C_G=; C_Y=; C_0=; fi
ok()   { printf '   %s✓%s %s\n' "$C_G" "$C_0" "$*"; }
skip() { printf '   %s•%s %s\n' "$C_B" "$C_0" "$*"; }
warn() { printf '   %s!%s %s\n' "$C_Y" "$C_0" "$*"; }
ask()  { local a; read -rp "   $* [y/N] " a </dev/tty; [[ "$a" =~ ^[Yy]$ ]]; }

rm_file() { if [ -e "$1" ] || [ -L "$1" ]; then rm -f "$1" && ok "removed $1"; else skip "already gone: $1"; fi; }
rm_tree() { if [ -e "$1" ]; then rm -rf "$1" && ok "removed $1/"; else skip "already gone: $1/"; fi; }
rm_sudo() { if [ -e "$1" ]; then sudo rm -f "$1" && ok "removed $1 (sudo)"; else skip "already gone: $1"; fi; }

disable_plugin() {
    kwriteconfig6 --file kwinrc --group Plugins --key "${1}Enabled" false 2>/dev/null \
        && ok "disabled KWin script: $1" || skip "KWin plugin $1 not set"
}

# Delete our KWin rule group (only our keys) and drop it from the shared Order list,
# leaving any other window rules you have untouched.
del_kwin_group() {
    local g="$1" k
    for k in Description decorationpolicy decorationpolicyrule wmclass wmclassmatch \
             acceptfocus acceptfocusrule position positionrule size sizerule \
             skippager skippagerrule skipswitcher skipswitcherrule skiptaskbar skiptaskbarrule; do
        kwriteconfig6 --file kwinrulesrc --group "$g" --key "$k" --delete 2>/dev/null || true
    done
    local order new=""
    order="$(kreadconfig6 --file kwinrulesrc --group General --key Order 2>/dev/null || true)"
    IFS=',' read -ra parts <<<"$order"
    for p in "${parts[@]}"; do [ -n "$p" ] && [ "$p" != "$g" ] && new="${new:+$new,}$p"; done
    if [ -n "$new" ]; then kwriteconfig6 --file kwinrulesrc --group General --key Order "$new"
    else kwriteconfig6 --file kwinrulesrc --group General --key Order --delete 2>/dev/null || true; fi
    ok "removed KWin rule group: $g"
}

printf '%smlbb-linux uninstaller%s\n' "$C_B" "$C_0"

CONFIG_DIR="$HOME/.config/mlbb-linux"
KWIN_TOUCHED=0

if [ -f "$MANIFEST" ]; then
    printf '\nUsing install manifest (%s)\n' "$MANIFEST"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        type="${line%%:*}"; val="${line#*:}"
        case "$type" in
            file)     rm_file "$val" ;;
            tree)     rm_tree "$val" ;;
            shared)   rm_file "$val" ;;                 # a shared-location file WE created (e.g. gamemode.ini)
            sudo)     if [ "$ALL" = 1 ]; then rm_sudo "$val"; else skip "kept system file (use --all to remove): $val"; fi ;;
            optional) if [ "$ALL" = 1 ]; then rm_tree "$val"; else skip "kept shared tool (use --all to remove): $val/"; fi ;;
            kwin)        del_kwin_group "$val"; KWIN_TOUCHED=1 ;;
            kwinplugin)  disable_plugin "$val"; KWIN_TOUCHED=1 ;;
            *) warn "unknown manifest line: $line" ;;
        esac
    done < "$MANIFEST"
    rm_file "$MANIFEST"
else
    warn "No manifest found. Removing only the files that are unambiguously ours, and"
    warn "leaving anything shared (gamemode.ini, udev rule, Docker drop-in, scrcpy-mask) alone."
    rm_file "$HOME/.local/bin/mlbb"
    rm_file "$HOME/.local/bin/mlbb-controls"
    rm_file "$HOME/.local/bin/mlbb-perf"
    rm_tree "$HOME/.local/share/mlbb-linux"
    rm_tree "$HOME/.local/share/kwin/scripts/mlbb-focus"
    rm_file "$HOME/.local/share/applications/mlbb-keyboard.desktop"
    del_kwin_group mlbb-waydroid; del_kwin_group mlbb-scrcpy-mask
    disable_plugin mlbb-focus
    KWIN_TOUCHED=1
fi

[ "$KWIN_TOUCHED" = 1 ] && { qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true; }

# Config: your settings. Kept unless --all.
if [ -d "$CONFIG_DIR" ]; then
    if [ "$ALL" = 1 ]; then rm_tree "$CONFIG_DIR"
    else skip "kept your settings at $CONFIG_DIR (remove with --all, or delete it yourself)"; fi
fi

echo
warn "Left in place on purpose (general tools / yours, not ours to remove):"
echo "     Waydroid, the ARM translator, your Android image and the game, your Google account."
id -nG | tr ' ' '\n' | grep -qx input    && echo "     Group membership: you are still in 'input' (harmless). Remove with: sudo gpasswd -d $USER input"
id -nG | tr ' ' '\n' | grep -qx gamemode && echo "     Group membership: you are still in 'gamemode' (harmless)."
printf '\n%s[done]%s\n' "$C_G" "$C_0"
