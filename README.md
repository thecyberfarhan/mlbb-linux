# mlbb-linux

> Play Mobile Legends: Bang Bang (MLBB) on Linux with a keyboard and mouse, the way an emulator like BlueStacks does it on Windows: the Android game in Waydroid, WASD on the joystick, keys on the skills, the mouse as touch, with full KDE Plasma integration.

It runs the game in [Waydroid](https://waydro.id/) with a launcher, a clean KDE
desktop integration, and a watchdog that unsticks the joystick. BlueStacks has no
Linux build, and Waydroid on its own has no keymapper, so this fills that gap.

Built and tested on **Arch Linux with KDE Plasma 6 (Wayland)**. Mobile Legends is
the tested profile; the layout is profile-based, so other Waydroid games can be
added.

> Convenience input remapping only (keyboard and mouse to touch), the same idea as
> BlueStacks. It is **not** a macro tool or a bot: one key maps to one tap. Keep it
> that way to stay within Mobile Legends' rules.

## At a glance

| | |
|---|---|
| Kind | Personal |
| Status | Public |
| Language | Bash, Python |
| Requires | Arch Linux, KDE Plasma (Wayland), Waydroid |
| License | MIT |

## What you get

- **WASD joystick + key-mapped skills + mouse-as-touch** through
  [scrcpy-mask](https://github.com/AkiChase/scrcpy-mask).
- **One launcher.** `mlbb start` brings up Android, the keymapper, the overlay and
  the desktop fixes, checks every piece, and repairs what is missing. `mlbb stop`
  tears it all down. `mlbb status` shows what is running.
- **Proper KDE integration.** The game and overlay stay above other windows only
  while focused (so Meta still shows the taskbar), the overlay sits exactly over
  the game, its stray 1px border is pushed off-screen, and minimizing from the
  taskbar works.
- **On-screen HUD buttons** (minimize, chat, back-to-game) styled like the in-match
  HUD, invisible until you hover the left edge.
- **A stuck-touch watchdog** that releases a joystick touch Android is still holding
  when no real key is pressed. It ignores virtual input devices so it cannot wedge.
- **Supersampling and smoother video** set automatically each boot.
- **Everything is dynamic:** the game monitor, resolution and Android serial are
  detected or read from config. No hardcoded paths, IPs or monitor names.

## Requirements

- **Arch Linux** (the installer uses `pacman`; other distros need the equivalent
  packages installed by hand).
- **KDE Plasma 6 on Wayland.** The focus, taskbar and overlay layer is built on
  KWin scripts and layer-shell, so GNOME and X11 are not supported.
- Waydroid with a **GAPPS** image (for Google Play), the **libndk** ARM translator,
  and a Google-certified device.
- An x86_64 CPU with enough single-thread speed (the game's main thread runs under
  ARM translation, which is the usual bottleneck).

## Install

```bash
git clone https://github.com/thecyberfarhan/mlbb-linux
cd mlbb-linux
./install.sh
```

The installer is idempotent and asks before any system change (set `MLBB_YES=1` to
accept all). It installs the scripts, the KWin script and rules, the udev rule and
the keymap, and walks you through the parts that need your own input: initializing
Waydroid, installing the ARM translator, and Google Play certification. Signing in
to Google Play and installing the game inside Android is yours to do.

Then:

```bash
mlbb start      # or launch "Mobile Legends (Keyboard)" from your app menu
```

## Controls

The keys in the bundled layout:

| Key | Action | | Key | Action |
|-----|--------|-|-----|--------|
| `W` `A` `S` `D` | Move (joystick) | | `Q` | Recall |
| Mouse | Aim / touch | | `Alt` | Extra spell |
| `Space` | Basic attack | | `Tab` | Scoreboard |
| `Shift` | Flicker / skill | | `Ctrl` | Shop |
| `E` | Regen | | `Z` | Quick buy |
| `Enter` | Chat (typing mode) | | | |

Two things to know before you rely on these:

- You can rebind any key.
- The on-screen **tap positions are placed for one specific Mobile Legends HUD** (a
  custom PC-friendly layout). Mobile Legends lets every player move their buttons
  around, so if yours sit in different spots the taps will miss. That is expected,
  not a bug: remap them to your own HUD once, as below.

### Remap to your own layout

1. Launch with `mlbb start` so the game and the scrcpy-mask overlay are up.
2. Run `mlbb remap`. Each binding's label appears on its tap so you can see what
   you are moving.
3. In the scrcpy-mask window, open its key-mapping editor and drag each binding
   onto the matching button in **your** HUD. Add, remove or rebind keys as you like.
4. Save in scrcpy-mask, then run `mlbb start` again to play (the labels hide
   automatically).

Tip: arrange your in-game HUD first (Mobile Legends > Settings > Controls >
Customize), then map the taps onto it. The raw coordinates live in
`profiles/mlbb/mapping.json`, in the profile's native resolution, if you prefer to
edit them by hand; see [docs/PROFILES.md](docs/PROFILES.md).

## Configure

```bash
mlbb config show     # resolved settings + what auto-detection currently finds
mlbb config edit     # open ~/.config/mlbb-linux/config.conf
```

You can pin a monitor, pin the Android serial, switch the monitor to 60 Hz for the
session (smoother on a 75 Hz panel without VRR), or add input devices for the
watchdog to ignore. Blank values mean "auto-detect".

## How it works

`mlbb start` starts the Waydroid session, waits for Android to boot and get an IP,
applies per-boot tuning (supersampling, faster video decode, no Google Assistant),
starts scrcpy-mask and connects it, activates your key layout, launches the game,
and focuses the overlay. A KWin script manages window stacking, focus and the
taskbar; a small PyQt6 layer-shell overlay shows the HUD buttons, tracks typing vs
game mode from scrcpy-mask's log, and runs the watchdog. See
[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for the problems this solves and
why each fix is there.

## FAQ

**Can you play Mobile Legends on Linux?** Yes. There is no official Linux client and
BlueStacks does not run on Linux, but Waydroid runs the Android game and this
project adds the keyboard-and-mouse controls and desktop integration around it.

**How do I use a keyboard and mouse for Mobile Legends on PC without BlueStacks?**
On Linux, run it in Waydroid and use this project: WASD is the joystick, keys are
the skills, and the mouse acts as touch, via scrcpy-mask.

**Does it work on GNOME or X11?** No. It relies on KDE Plasma (KWin) and Wayland
layer-shell. GNOME or X11 support would need a different windowing layer.

**Is this a cheat, macro or bot?** No. It is a one-key-to-one-tap input remapper, the
same convenience BlueStacks provides. It does not automate gameplay.

**Will it work for other Waydroid games?** The structure supports per-game profiles.
Mobile Legends is the one that is tested; see [docs/PROFILES.md](docs/PROFILES.md)
to add another.

## Credits and license

Stands on [Waydroid](https://waydro.id/),
[scrcpy-mask](https://github.com/AkiChase/scrcpy-mask),
[waydroid_script](https://github.com/casualsnek/waydroid_script) and
[gamemode](https://github.com/FeralInteractive/gamemode). Mobile Legends: Bang Bang
is a trademark of Moonton; this project is not affiliated with or endorsed by
Moonton.

Licensed under the [MIT License](LICENSE).
