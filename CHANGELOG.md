# Changelog

## Unreleased

- `mlbb remap`: show the key labels and walk you through moving the on-screen taps
  onto your own Mobile Legends HUD, since the bundled positions match one specific
  custom layout. `mlbb start` now hides the labels for play.

## 1.0.0

First public release. Play Mobile Legends on Linux (Waydroid) with a keyboard and
mouse on KDE Plasma (Wayland).

- Launcher `mlbb start|stop|status|setup|config` that brings up Android, the
  keymapper, the overlay and the KDE fixes, verifies every piece, and repairs what
  is missing.
- scrcpy-mask keymapping with an MLBB profile (WASD joystick, mapped skills, mouse
  as touch).
- KWin script for focus, taskbar behaviour, overlay stacking, the off-screen border
  trick, and minimize sync.
- PyQt6 layer-shell HUD overlay (minimize / chat / back-to-game), invisible until
  hovered, with a stuck-touch watchdog that ignores virtual input devices.
- Per-boot tuning: supersampling, faster video decode, Assistant disabled.
- Config + profile driven: game monitor, resolution and Android serial are detected
  or configured, nothing hardcoded.
- Arch-first installer that is interruption-safe and idempotent, records everything
  it creates in a manifest, and an uninstaller that removes only what that manifest
  lists (your pre-existing files are never touched).
