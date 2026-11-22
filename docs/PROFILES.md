# Adding another game

mlbb-linux is built around Mobile Legends, but the game-specific half lives in a
profile, so another Waydroid game can be added without touching the scripts. Only
the MLBB profile is tested; treat a new one as your own tuning.

A profile is a folder under `profiles/<name>/` with two files:

- `profile.conf` — the package, launch activity, resolution and render settings.
- `mapping.json` — the scrcpy-mask key layout (tap coordinates for that game's HUD).

## 1. Find the package and activity

With the game installed in Waydroid and a session running:

```bash
ADB=~/.local/share/scrcpy-mask/app/assets/platform-tools/adb
# package name:
"$ADB" shell pm list packages | grep -i <game>
# launch activity (open the game once, then):
"$ADB" shell dumpsys window | grep -i mCurrentFocus
```

Put those in `profile.conf` as `PKG` and `ACTIVITY`. Set `GAME_PROC` to the game's
process suffix if you know it (optional), and `MAIN_THREAD` to its render thread for
`mlbb-perf` (Unity games use `UnityMain`).

## 2. Set the resolution

`GAME_WIDTH` / `GAME_HEIGHT` is the coordinate space your `mapping.json` taps are in
(1920x1080 for the MLBB profile). `RENDER_WIDTH` / `RENDER_HEIGHT` / `DENSITY` are the
optional supersample (render bigger, scale down); leave `RENDER_WIDTH` blank to skip.

## 3. Author the key layout

Easiest path: launch with the MLBB profile once, open the scrcpy-mask window, and use
its own editor to place taps on the new game's buttons, then save. Or copy
`profiles/mlbb/mapping.json` and edit the `position` of each entry.

Tap coordinates are in the `GAME_WIDTH x GAME_HEIGHT` space. To read a button's
coordinate, take a screenshot at that resolution and measure:

```bash
"$ADB" exec-out screencap -p > shot.png
```

Keep it to one key per tap (`SingleTap`) and the joystick as the `DirectionPad`. Do
not build multi-tap combo macros: that crosses into automation the game's rules
forbid.

## 4. Point the config at it

```bash
cp -r profiles/mlbb "$HOME/.local/share/mlbb-linux/profiles/<name>"   # then edit it
mlbb config edit        # set PROFILE="<name>"
mlbb setup              # installs that profile's mapping and re-renders the KWin script
mlbb start
```

`mlbb setup` copies the profile's `mapping.json` into scrcpy-mask as `<name>.json`,
activates it, and renders the KWin script at that profile's resolution.
