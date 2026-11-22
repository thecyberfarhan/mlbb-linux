#!/usr/bin/env bash
# mlbb-linux installer (Arch-first). Safe to interrupt, safe to re-run.
#
# Design notes:
#   * Idempotent: every step checks whether it is already done, so re-running after
#     a power cut, Ctrl-C or a killed terminal simply resumes.
#   * It records everything it actually creates in an install manifest
#     (~/.local/state/mlbb/install-manifest). The uninstaller removes ONLY what is
#     in that manifest, so files you already had (e.g. a pre-existing gamemode.ini)
#     are never recorded and never removed.
#   * Nothing is left in a broken state on interruption. The one genuinely risky op
#     (the ARM translator) is only ever an "install", never a "remove-then-install".
#
# What stays manual (they need YOUR account/choices): signing in to Google Play,
# installing the game, and Google Play device certification.
set -uo pipefail   # not -e: errors are handled per step so traps can report cleanly

# --- paths (override before running if you want them elsewhere) ---------------
BIN="${MLBB_BIN_DIR:-$HOME/.local/bin}"
DATA="${MLBB_DATA:-$HOME/.local/share/mlbb-linux}"
MASK_APP="${MLBB_SCRCPY_DIR:-$HOME/.local/share/scrcpy-mask/app}"
KWIN_DIR="$HOME/.local/share/kwin/scripts/mlbb-focus"
APPS="$HOME/.local/share/applications"
STATE="$HOME/.local/state/mlbb"
MANIFEST="$STATE/install-manifest"
LOGFILE="$STATE/install.log"
WAYDROID_SCRIPT="$HOME/.local/share/waydroid_script"
MASK_URL="https://github.com/AkiChase/scrcpy-mask/releases/download/v0.9.0/scrcpy-mask-linux-x64.zip"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YES="${MLBB_YES:-0}"

mkdir -p "$STATE"
: >>"$MANIFEST"

# --- pretty output + logging -------------------------------------------------
if [ -t 1 ]; then C_B=$'\033[1m'; C_C=$'\033[1;36m'; C_G=$'\033[1;32m'; C_Y=$'\033[1;33m'; C_R=$'\033[1;31m'; C_0=$'\033[0m'
else C_B=; C_C=; C_G=; C_Y=; C_R=; C_0=; fi
STEP=0; TOTAL=9
log()  { printf '%s\n' "$(date '+%F %T') | $*" >>"$LOGFILE"; }
step() { STEP=$((STEP+1)); printf '\n%s[%d/%d]%s %s%s%s\n' "$C_C" "$STEP" "$TOTAL" "$C_0" "$C_B" "$*" "$C_0"; log "STEP $STEP: $*"; }
ok()   { printf '   %s✓%s %s\n' "$C_G" "$C_0" "$*"; log "ok: $*"; }
skip() { printf '   %s•%s %s\n' "$C_B" "$C_0" "$*"; log "skip: $*"; }
warn() { printf '   %s!%s %s\n' "$C_Y" "$C_0" "$*"; log "warn: $*"; }
err()  { printf '   %s✗%s %s\n' "$C_R" "$C_0" "$*"; log "err: $*"; }
ask()  { [ "$YES" = 1 ] && return 0; local a; read -rp "   $* [y/N] " a </dev/tty; [[ "$a" =~ ^[Yy]$ ]]; }
prompt() { local a; read -rp "   $1 " a </dev/tty; printf '%s' "${a:-$2}"; }
have() { command -v "$1" >/dev/null 2>&1; }
# record <type>:<value> in the manifest (deduplicated). Types: file, tree, shared, sudo, kwin.
record() { grep -qxF "$1" "$MANIFEST" 2>/dev/null || printf '%s\n' "$1" >>"$MANIFEST"; }

# --- interruption / failure handling -----------------------------------------
DONE=0
on_exit() {
    local rc=$?
    if [ "$DONE" != 1 ]; then
        printf '\n%s[stopped]%s before finishing (exit %s).\n' "$C_Y" "$C_0" "$rc"
        printf '   Nothing was left half-removed. Re-run %s./install.sh%s to resume where it left off.\n' "$C_B" "$C_0"
        printf '   Log: %s\n' "$LOGFILE"
    fi
}
on_int() { printf '\n%s[interrupted]%s\n' "$C_Y" "$C_0"; exit 130; }
trap on_exit EXIT
trap on_int INT TERM

printf '%smlbb-linux installer%s  (log: %s)\n' "$C_B" "$C_0" "$LOGFILE"

# --- 0. environment + choices ------------------------------------------------
step "Checking your environment"
if [ "${XDG_SESSION_TYPE:-}" = "x11" ]; then warn "You are on X11; the overlay needs Wayland. Log in to a Plasma (Wayland) session."; fi
case "${XDG_CURRENT_DESKTOP:-}${KDE_FULL_SESSION:-}" in
    *KDE*|*true*) ok "KDE Plasma detected";;
    *) warn "This targets KDE Plasma (Wayland). It will not work on GNOME or other desktops.";;
esac
have pacman && ok "Arch (pacman) detected" || warn "Not Arch: you will install packages by hand (see below)."

printf '\n   %sThis will install into:%s\n' "$C_B" "$C_0"
printf '     scripts   %s\n     data      %s\n     keymapper %s\n' "$BIN" "$DATA" "$MASK_APP"
if ask "Customize these locations?"; then
    BIN="$(prompt "scripts dir [$BIN]:" "$BIN")"
    DATA="$(prompt "data dir [$DATA]:" "$DATA")"
    MASK_APP="$(prompt "scrcpy-mask dir [$MASK_APP]:" "$MASK_APP")"
fi

printf '\n   %sHow will you get Mobile Legends inside Android?%s\n' "$C_B" "$C_0"
printf '     1) Google Play  (recommended; needs Play certification, done below)\n'
printf '     2) Sideload an APK file you already have\n'
GAME_SRC="$(prompt "Choose [1/2, default 1]:" "1")"
GAME_APK=""
if [ "$GAME_SRC" = "2" ]; then
    GAME_APK="$(prompt "Full path to the .apk (you can also do this later):" "")"
    GAME_APK="${GAME_APK/#\~/$HOME}"
    if [ -n "$GAME_APK" ] && [ ! -f "$GAME_APK" ]; then warn "No file at '$GAME_APK' yet; I'll remind you how to install it at the end."; fi
fi

# --- 1. packages -------------------------------------------------------------
step "Installing system packages"
PACKAGES=(waydroid python python-pyqt6 qt6-declarative qt6-shadertools qt6-5compat qt6-svg layer-shell-qt gamemode curl unzip libnotify)
if have pacman; then
    if ask "Run: sudo pacman -S --needed ${PACKAGES[*]} ?"; then
        if sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"; then ok "packages installed"; else err "pacman failed; fix it and re-run"; exit 1; fi
    else skip "package install declined (make sure they are present)"; fi
else
    warn "Install equivalents yourself: PyQt6, Qt6 Declarative/ShaderTools/5Compat/Svg,"
    warn "the org.kde.layershell QML module, gamemode, curl, unzip, libnotify, waydroid."
fi

# --- 2. scripts, profiles, KWin script, menu entry ---------------------------
step "Installing scripts, profiles and the KWin script"
mkdir -p "$BIN" "$DATA" "$APPS" "$KWIN_DIR/contents/code"
record "tree:$DATA"; record "tree:$KWIN_DIR"
install -m 755 "$SCRIPT_DIR/bin/mlbb" "$SCRIPT_DIR/bin/mlbb-controls" "$SCRIPT_DIR/bin/mlbb-perf" "$BIN/"
record "file:$BIN/mlbb"; record "file:$BIN/mlbb-controls"; record "file:$BIN/mlbb-perf"
cp -r "$SCRIPT_DIR/profiles" "$DATA/"
cp "$SCRIPT_DIR/config/config.example.conf" "$DATA/"
cp "$SCRIPT_DIR/kwin/mlbb-focus/metadata.json" "$KWIN_DIR/"
cp "$SCRIPT_DIR/kwin/mlbb-focus/contents/code/main.js.in" "$KWIN_DIR/contents/code/"
sed -e "s|@@BIN@@|$BIN|g" \
    -e "s|@@ICON@@|$HOME/.local/share/waydroid/data/icons/com.mobile.legends.png|g" \
    "$SCRIPT_DIR/config/mlbb-keyboard.desktop.in" > "$APPS/mlbb-keyboard.desktop"
record "file:$APPS/mlbb-keyboard.desktop"
ok "scripts in $BIN, data in $DATA"
case ":$PATH:" in *":$BIN:"*) ;; *) warn "$BIN is not on your PATH; add it to your shell rc.";; esac

# --- 3. udev rule + groups ---------------------------------------------------
step "Input access (/dev/uinput) and groups"
if [ -f /etc/udev/rules.d/99-mlbb-uinput.rules ]; then skip "udev rule already installed"
elif ask "Install the /dev/uinput udev rule (sudo)?"; then
    if sudo install -m 644 "$SCRIPT_DIR/config/99-mlbb-uinput.rules" /etc/udev/rules.d/99-mlbb-uinput.rules; then
        sudo udevadm control --reload-rules && sudo udevadm trigger
        record "sudo:/etc/udev/rules.d/99-mlbb-uinput.rules"; ok "udev rule installed"
    else err "could not install udev rule"; fi
else skip "udev rule declined"; fi
for grp in input gamemode; do
    if getent group "$grp" >/dev/null && ! id -nG | tr ' ' '\n' | grep -qx "$grp"; then
        if ask "Add you to the '$grp' group?"; then sudo usermod -aG "$grp" "$USER" && { NEED_RELOGIN=1; ok "added to $grp"; }; fi
    else skip "already in '$grp' (or no such group)"; fi
done

# --- 4. gamemode.ini (only if you don't already have one) --------------------
step "gamemode configuration"
if [ -f "$HOME/.config/gamemode.ini" ]; then
    skip "you already have ~/.config/gamemode.ini (left untouched)"
else
    install -m 644 "$SCRIPT_DIR/config/gamemode.ini" "$HOME/.config/gamemode.ini" \
        && { record "shared:$HOME/.config/gamemode.ini"; ok "installed ~/.config/gamemode.ini"; }
fi

# --- 5. Waydroid -------------------------------------------------------------
step "Waydroid container and network"
if have waydroid; then
    sudo systemctl enable --now waydroid-container 2>/dev/null && ok "waydroid-container active" || warn "could not start waydroid-container"
    if [ -f /var/lib/waydroid/waydroid.cfg ]; then skip "Waydroid already initialized"
    elif ask "Initialize Waydroid with a GAPPS image now (large download)?"; then
        sudo waydroid init -s GAPPS && ok "Waydroid initialized" || err "waydroid init failed (re-run to retry)"
    else warn "Waydroid not initialized; run 'sudo waydroid init -s GAPPS' before first launch"; fi
    if have docker; then
        if [ -f /etc/systemd/system/waydroid-container.service.d/docker-forward.conf ]; then skip "Docker network drop-in already present"
        elif ask "Docker is installed; add the Waydroid network drop-in so Android has internet?"; then
            sudo mkdir -p /etc/systemd/system/waydroid-container.service.d
            sudo install -m 644 "$SCRIPT_DIR/systemd/waydroid-container.service.d/docker-forward.conf" \
                 /etc/systemd/system/waydroid-container.service.d/docker-forward.conf \
                && { record "sudo:/etc/systemd/system/waydroid-container.service.d/docker-forward.conf"
                     sudo systemctl daemon-reload; sudo systemctl restart waydroid-container || true; ok "network drop-in installed"; }
        fi
    fi
else warn "waydroid not installed; install it, then re-run"; fi

# --- 6. ARM translator (libndk) ----------------------------------------------
step "ARM translation layer (libndk)"
if [ -d "$WAYDROID_SCRIPT" ] && grep -q libndk <(ls "$HOME/.cache/waydroid-script/downloads" 2>/dev/null) 2>/dev/null; then
    skip "libndk appears already fetched"
fi
if ask "Set up waydroid_script and install the libndk translator?"; then
    [ -d "$WAYDROID_SCRIPT" ] || git clone --depth 1 https://github.com/casualsnek/waydroid_script "$WAYDROID_SCRIPT"
    ( cd "$WAYDROID_SCRIPT"
      [ -d venv ] || python3 -m venv venv
      venv/bin/pip install -q -r requirements.txt
      warn "Large download on a slow link. Do NOT interrupt mid-download: this step only"
      warn "installs libndk (never removes a working translator first), so a retry is safe."
      sudo venv/bin/python3 main.py install libndk ) && ok "libndk installed" || err "translator step failed (re-run to retry)"
    warn "Google Play certification is manual:"
    warn "  sudo $WAYDROID_SCRIPT/venv/bin/python3 main.py certified"
    warn "  then register the printed device ID at https://www.google.com/android/uncertified/"
else skip "translator step declined"; fi

# --- 7. scrcpy-mask ----------------------------------------------------------
step "scrcpy-mask keymapper (v0.9.0)"
if [ -x "$MASK_APP/scrcpy-mask" ]; then skip "already installed at $MASK_APP"
elif ask "Download scrcpy-mask v0.9.0 from GitHub?"; then
    tmp="$(mktemp -d)"
    if curl -fL "$MASK_URL" -o "$tmp/m.zip"; then
        mkdir -p "$MASK_APP"; unzip -oq "$tmp/m.zip" -d "$MASK_APP"
        if [ ! -x "$MASK_APP/scrcpy-mask" ]; then
            inner="$(find "$MASK_APP" -maxdepth 2 -name scrcpy-mask -type f | head -1)"
            [ -n "$inner" ] && cp -r "$(dirname "$inner")/." "$MASK_APP/"
        fi
        chmod +x "$MASK_APP/scrcpy-mask" "$MASK_APP/run.sh" 2>/dev/null || true
        # "optional": ours, but a general tool you might reuse, so uninstall keeps it unless --all.
        record "optional:$MASK_APP"; ok "scrcpy-mask installed"
    else err "download failed (re-run to retry)"; fi
    rm -rf "$tmp"
else skip "scrcpy-mask download declined"; fi

# --- 8. KWin window rules + enable the focus script --------------------------
step "KWin window rules and focus script"
add_rule() { kwriteconfig6 --file kwinrulesrc --group "$1" --key "$2" "$3"; }
order="$(kreadconfig6 --file kwinrulesrc --group General --key Order 2>/dev/null || true)"
for g in mlbb-waydroid mlbb-scrcpy-mask; do case ",$order," in *",$g,"*) ;; *) order="${order:+$order,}$g";; esac; done
kwriteconfig6 --file kwinrulesrc --group General --key Order "$order"
add_rule mlbb-scrcpy-mask Description "MLBB: scrcpy-mask window"
add_rule mlbb-scrcpy-mask decorationpolicy none; add_rule mlbb-scrcpy-mask decorationpolicyrule 2
add_rule mlbb-scrcpy-mask wmclass scrcpy-mask; add_rule mlbb-scrcpy-mask wmclassmatch 1
add_rule mlbb-waydroid Description "MLBB: Waydroid window"
add_rule mlbb-waydroid acceptfocus false; add_rule mlbb-waydroid acceptfocusrule 2
add_rule mlbb-waydroid decorationpolicy none; add_rule mlbb-waydroid decorationpolicyrule 2
add_rule mlbb-waydroid position 0,0; add_rule mlbb-waydroid positionrule 2
add_rule mlbb-waydroid size 1920,1080; add_rule mlbb-waydroid sizerule 2
for k in skippager skipswitcher skiptaskbar; do add_rule mlbb-waydroid "$k" true; add_rule mlbb-waydroid "${k}rule" 2; done
add_rule mlbb-waydroid wmclass Waydroid; add_rule mlbb-waydroid wmclassmatch 1
record "kwin:mlbb-waydroid"; record "kwin:mlbb-scrcpy-mask"
kwriteconfig6 --file kwinrc --group Plugins --key mlbb-focusEnabled true
record "kwinplugin:mlbb-focus"
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
ok "window rules added and focus script enabled"

# --- 9. per-machine setup ----------------------------------------------------
step "Per-machine setup (mapping + resolution + config)"
MLBB_DATA="$DATA" MLBB_BIN_DIR="$BIN" "$BIN/mlbb" setup && ok "setup complete" || warn "run 'mlbb setup' again after finishing the steps above"
if [ -n "$GAME_APK" ]; then
    printf 'GAME_APK="%s"\n' "$GAME_APK" >> "$HOME/.config/mlbb-linux/config.conf" 2>/dev/null || true
fi

# --- done --------------------------------------------------------------------
DONE=1
printf '\n%s[done]%s mlbb-linux is installed.\n' "$C_G" "$C_0"
[ -n "${NEED_RELOGIN:-}" ] && warn "Log out and back in once so your new group membership takes effect."
echo
printf '%sFinish these, then play:%s\n' "$C_B" "$C_0"
echo "  1. If you declined any step above, re-run ./install.sh to resume it."
echo "  2. Certify Google Play (see the command printed above) and install the game:"
if [ "$GAME_SRC" = "2" ]; then
    echo "       APK: start the session, then run"
    echo "       $MASK_APP/assets/platform-tools/adb install \"${GAME_APK:-/path/to/mlbb.apk}\""
else
    echo "       Open the Play Store inside Android and install Mobile Legends."
fi
echo "  3. Launch:  mlbb start   (or the \"Mobile Legends (Keyboard)\" menu entry)"
echo "     Check:   mlbb status      Settings: mlbb config edit"
