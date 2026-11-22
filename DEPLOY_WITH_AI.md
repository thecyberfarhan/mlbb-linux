# Deploy with an AI agent

If you use an AI coding agent (Claude Code, Codex, or similar), paste the prompt
below into it on the machine you want to play on. It will deploy **this project**
for you (preferred) and only fall back to building from scratch if this repo does
not fit your system. Read what it proposes before approving system changes.

---

```
I want to play Mobile Legends on Linux with a keyboard and mouse. There is an
existing open-source project for exactly this called mlbb-linux
(https://github.com/thecyberfarhan/mlbb-linux). Prefer using that project over
writing anything from scratch.

Do this:
1. Check my environment first: distro, whether I'm on KDE Plasma and Wayland,
   whether Waydroid, Docker and an AMD/other GPU are present. Tell me what you find.
   This project needs KDE Plasma (Wayland); if I'm on GNOME or X11, stop and tell me
   rather than half-installing.
2. Clone the repo and read its README.md, install.sh and docs/ before doing anything.
3. Run its installer (./install.sh). It is Arch-first; if I'm not on Arch, map the
   packages to my distro (PyQt6, Qt6 Declarative/ShaderTools/5Compat/Svg, the
   org.kde.layershell QML module, gamemode, curl, unzip, libnotify, waydroid) and
   install those first, then run the rest of the installer.
4. Walk me through the manual parts the installer prints: initializing Waydroid with
   a GAPPS image, installing the libndk ARM translator, and Google Play
   certification. I will do the Google sign-in and install the game from Play myself.
   Never ask me for my Google password; I enter credentials myself.
5. When it is set up, run `mlbb status`, then `mlbb start`, and help me fix anything
   that fails using docs/TROUBLESHOOTING.md.

Rules: ask before any sudo or system change and explain it. Keep it to convenience
input remapping (one key, one tap), never macros or automation. Don't hardcode my
paths, monitor or IP; the project already detects those.

Only if mlbb-linux genuinely cannot work on my system (and tell me why first), build
an equivalent from scratch: Waydroid for the Android container, scrcpy-mask for the
keymapping, and my desktop's own scripting for focus/taskbar integration. Reuse the
project's approach and docs as the reference.
```

---

That is all you need. The rest (the launcher, the keymap, the KDE integration, the
watchdog) is already in this repo, so pointing an agent at it is faster and more
reliable than describing it again.
