# Troubleshooting

The real problems hit while building this, and the fix for each. Most are already
handled by the scripts; this explains what and why, and what to do if one comes back.

## Android has no internet inside Waydroid
Docker sets the iptables `FORWARD` policy to DROP, which also drops traffic from
Waydroid's `waydroid0` bridge. The installer adds a systemd drop-in
(`waydroid-container.service.d/docker-forward.conf`) that re-adds `DOCKER-USER`
ACCEPT rules before the container starts, only when Docker is present. One-off fix:
```bash
sudo iptables -I DOCKER-USER -i waydroid0 -j ACCEPT
sudo iptables -I DOCKER-USER -o waydroid0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
```

## The game ignores mouse clicks
Waydroid must treat mouse input as touch for the game package:
```bash
waydroid prop set persist.waydroid.fake_touch com.mobile.legends
```
then restart the session. (The installer sets this up for the active profile.)

## The game renders dimmed after an interruption
Opening Recents or an overlay (for example Google Assistant on a stray Meta press)
can leave the game dimmed. The only reliable cure is restarting the game. To prevent
it, the launcher disables the Assistant each boot. Do not hover the bottom edge to
show the Android navigation bar (all mouse input is touch); swipe up from the bottom
instead.

## A thin red border around the overlay
scrcpy-mask draws a 1px border that cannot be turned off. The KWin script makes the
overlay 2px larger than the game monitor on every side so the border lands
off-screen. If you see it, the KWin script is not loaded (`mlbb status`).

## The taskbar won't come up / the game stays on top
The KWin script keeps the game and overlay above other windows only while the
overlay is focused. Press Meta or click another window and the taskbar returns. If
not, the script is not loaded; `mlbb start` reloads it.

## Can't minimize from the taskbar
Clicking the taskbar moves focus first, so the click doesn't minimize. Use the
minimize button in the on-screen HUD (hover the left edge), which minimizes through
KWin and takes the hidden Waydroid window with it.

## The joystick is stuck (hero keeps walking with no key held)
Three causes, all handled:
- **Reconnecting while a key is held** drops the control channel before the touch is
  released. The "back to game" button now uses scrcpy-mask's own exit (hold
  right-click >= 1s) instead of reconnecting; reconnect is only a fallback and is
  followed by a touch CANCEL.
- **Entering typing mode while moving:** scrcpy-mask releases nothing on that switch.
  The overlay sends a touch CANCEL on every live "Enter raw input mode" log line.
- **Anything else:** the watchdog releases a touch Android still holds when no real
  key or mouse button is pressed. If it ever seems stuck, check `mlbb.log` for a
  `watchdog:` line. The watchdog ignores virtual input devices (RustDesk, fake-mouse
  libraries, its own); add more names with `WATCHDOG_IGNORE` in the config if some
  virtual device on your system reports a permanently-held key.

## Stuck in typing mode (keys type into chat instead of moving)
Click the crossed-swords ("back to game") button on the HUD. It holds the virtual
right-click to trigger scrcpy-mask's own exit from typing mode.

## "Android didn't finish booting" on a cold start
`adb connect` exits 0 even when adbd is still starting. The launcher now checks the
device list and retries the connection inside the boot wait, and requires
`sys.boot_completed`. If it still times out, the image or translator may be missing;
see the install steps.

## It launched the emulator but no buttons / no keymapper
`mlbb start` ends with a `verify_all` pass that repairs each missing piece and only
reports "Ready" when everything is confirmed. Run `mlbb start` again, or `mlbb
status` to see which piece is down, then check `~/.local/state/mlbb/mlbb.log`.

## Windows land in the wrong place after rearranging monitors
Everything auto-detects the landscape game-resolution output now, so this should fix
itself. If you have more than one output at the game resolution, pin the connector
with `MONITOR=` in the config (`mlbb config edit`).

## Refresh rate looks wrong (judder)
Android reads the refresh rate only at session start. Stop and start again after
changing it. On a 75 Hz panel without VRR the 60 fps game judders; set
`REFRESH_MODE="60"` to lock the monitor to 60 Hz for the session.

## gamemode isn't raising priority
`renice` needs you in the `gamemode` group; the installer adds you, but you must log
out and back in once for it to take effect.

## Never run synthetic-input tests on the live desktop
Sending fake keys or forcing a scrcpy-mask reconnect while playing once crashed KWin.
Verify through logs (`dumpsys input`, scrcpy-mask's `app.log`, the journal) instead,
and do not inject input during a match.
