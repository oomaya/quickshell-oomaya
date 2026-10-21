# Sovereign Fleet Synchronization & Tailscale Dispatcher Guide

> **Author**: Antigravity Technical Lead & Implementer  
> **Target Audience**: Human Developers & AI Coding Agents (Gemini, Claude, Antigravity)  
> **Scope**: Fleet-wide synchronization across Omarchy (Hyprland/Wayland) and DWM/Quickshell (X11)  
> **Source of Truth**: `~/dotfiles/install.sh`, `~/.local/bin/fleet-sync`  

---

## 1. Quick Reference: Cheatsheet

| Command | Action | Use Case |
| :--- | :--- | :--- |
| `fleet-sync` | Synchronize local machine only | Daily development on current node |
| `fleet-sync --fleet --dry-run` | Preview fleet targets & RTT without execution | Pre-flight safety check before rollout |
| `fleet-sync --fleet` | Canary rollout $\rightarrow$ Sequential dispatch to all online peers | Standard fleet-wide release |
| `fleet-sync --fleet --nodes fedora44-vm` | Canary rollout $\rightarrow$ Target specific node only | Isolated multi-distro test / canary |
| `fleet-sync --fleet --parallel` | Concurrent dispatch across all online nodes | High-speed fleet rollout |
| `fleet-check` | Run automated 80+ health checks on local machine | Sanity audit of symlinks, agents & daemons |

---

## 2. Architecture & Mental Model

```mermaid
flowchart TD
    subgraph Control Tower (e.g. mint-vm)
        CMD["$ fleet-sync --fleet"] --> C["🐤 Canary Gate (Local)\n(verify.sh == 0 Failed)"]
        C -- Fail --> ABORT["🛑 CANARY ABORT\n(Zero remote mutation)"]
        C -- Pass --> D["🌐 Tailscale Status Discovery\n(Filter offline & non-Linux)"]
    end

    subgraph Zero-Trust WireGuard Mesh (Tailscale SSH)
        D ==> N1["🖥️ fedora44-vm (X11/dwm)\n(Build C core, install QML, reload)"]
        D ==> N2["💻 omarchy-vm (Hyprland)\n(Stow dotfiles, reload Hyprland)"]
        D ==> N3["💻 omarchy-gram (Hyprland)\n(Stow dotfiles, refresh menu/bar)"]
    end

    subgraph Per-Node Isolated Telemetry
        N1 --> L1["~/.local/state/dotfiles/fleet-logs/<ts>/fedora44-vm.log"]
        N2 --> L2["~/.local/state/dotfiles/fleet-logs/<ts>/omarchy-vm.log"]
        N3 --> L3["~/.local/state/dotfiles/fleet-logs/<ts>/omarchy-gram.log"]
    end
```

### 3 Fundamental Pillars
1. **The Worker (`install.sh --sync`)**:
   - Executes local Git pull, GNU Stow, Neovim plugin sync, and desktop stack compilation (`dwm-oomaya`, `quickshell-oomaya`).
   - Self-updating: if `install.sh` updates during sync, it automatically re-executes itself.
2. **The Highway (Tailscale Mesh + Tailscale SSH)**:
   - Provides peer-to-peer WireGuard encrypted routing across NATs, home routers, and VMs.
   - Zero SSH key management: identity-based mutual TLS authentication.
3. **The Dispatcher (`fleet-sync --fleet`)**:
   - Centralized control plane that enforces the **Canary Gate** before broadcasting orders across the highway.

---

## 3. The Canary-First Safety Rail (0-Failed Gate)

Whenever `--fleet` is invoked, the dispatcher **NEVER** touches remote machines until the local canary node passes:
1. **Execution**: Runs `./install.sh --sync` on the orchestrating host (`mint-vm`).
2. **The 0-Failed Rule**:
   - **Hard Failures (`Failed > 0` or exit code != 0)**: Rollout immediately halts. Zero remote commands are executed.
   - **Benign Warnings Tolerated**: Warnings (such as `omarchy-ctl DEGRADED` on X11 nodes) are tolerated and surfaced verbatim in the final summary. This prevents permanent lockouts on healthy desktop configurations.

---

## 4. Multi-Desktop Stack Synchronization

`fleet-sync` dynamically inspects the local machine profile and checked-out repositories:

### A. Omarchy Fleet (`omarchy` profile: Hyprland / Wayland)
- Managed via `~/dotfiles` packages (`omarchy`, `hyprland`, `nirify`, `kitty`, `ghostty`).
- Triggers `hyprctl reload`, `omarchy restart terminal`, theme hooks, and Lazy.nvim plugins.

### B. DWM / Quickshell Fleet (`workstation` profile: X11)
- Automatically checks for `~/.local/src/dwm-oomaya` and `~/.local/src/quickshell-oomaya`:
  1. `dwm-oomaya`: `git pull --rebase` $\rightarrow$ `make all` $\rightarrow$ deploys `dwm-shell-mode`, `dwm-status`, `autostart.sh` to `~/.local/bin/`.
  2. `quickshell-oomaya`: `git pull --rebase` $\rightarrow$ `make all` $\rightarrow$ `make install` (`~/.config/quickshell` and helper binaries).
  3. **Live Shell Reload**: Preserves the active window manager PID and hot-reloads the sub-shell mode (`dwm-shell-mode quickshell`).

---

## 5. Troubleshooting & Gotchas for AI Agents

1. **Headless SSH Display Context**:
   - Remote SSH commands do not inherit GUI variables.
   - The dispatcher automatically injects:
     `export DISPLAY="${DISPLAY:-:0}"; export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"; export PATH="$HOME/.local/bin:$PATH"`
2. **Inspecting Per-Node Execution Logs**:
   - Logs are persisted line-by-line:
     `ls -la ~/.local/state/dotfiles/fleet-logs/<TIMESTAMP>/`
   - Check exit code and duration: `cat <node>.rc` (e.g. `0 31` means rc=0 in 31s).
   - Check stdout/stderr: `view_file <node>.log`.
3. **Theme Security Barrier (`! -L`)**:
   - `dwm-settings-theme` explicitly forbids symlinked theme configurations for security.
   - Never symlink `themes.toml`; always copy regular files (`cp -f`).
4. **Offline Nodes**:
   - Offline nodes (e.g. suspended VMs or battery laptops) are marked `[SKIPPED (offline)]` without failing the rollout.
