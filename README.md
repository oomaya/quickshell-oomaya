# quickshell-oomaya

Optional Qt6/QML Desktop Shell and Widgets Companion for [dwm-oomaya](https://github.com/oomaya/dwm-oomaya).

## Overview
`quickshell-oomaya` provides modern Qt6/QML desktop overlays, including:
- Topbar panel and systray widgets
- Floating application launcher and quick-search
- Modern Control Center (Wi-Fi, Bluetooth, Audio, Brightness, Power)
- Lock screen and OSD indicators
- Native X11 EWMH IPC state bridge (`dwm-quickshell-state`)

This repository is maintained as an optional companion plugin for users who desire modern Qt6 graphical shell layers alongside the sovereign C `dwm-oomaya` window manager.

## Prerequisites
- Linux with X11 session
- Qt 6 (6.6+) & QML runtime
- [quickshell](https://quickshell.outfoxxed.me/) (v0.1.0+)
- `libX11` development libraries (for state bridge)
- `dwm-oomaya`

## Installation

```bash
git clone https://github.com/oomaya/quickshell-oomaya.git ~/.local/src/quickshell-oomaya
cd ~/.local/src/quickshell-oomaya
make install
```

To enable in dwm-oomaya:
```bash
dwm-shell-mode quickshell
```

To switch back to pure Suckless C mode:
```bash
dwm-shell-mode suckless
```

## Testing

```bash
make check
```

## License
MIT / GPL-3.0 (matching dwm-oomaya).
