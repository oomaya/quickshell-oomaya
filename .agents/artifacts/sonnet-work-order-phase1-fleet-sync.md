# Work Order for Implementer (Claude 3.5 Sonnet)
## Task: Phase 1 — Reinforce `dotfiles/install.sh` for Autonomous DWM & Quickshell Sync

> **Assignee**: Claude 3.5 Sonnet (Implementer / Systems Coder)  
> **Reviewer**: Gemini 2.5 Pro (Tech Lead / Systems Architect)  
> **Approver / Sign-Off**: Human Partner (User)  
> **Target File**: `/home/rand/dotfiles/install.sh`  
> **Safety Level**: High (Mission-Critical Fleet Bootstrapper)  

---

### 1. Architectural Mission
Reinforce the local worker engine (`~/dotfiles/install.sh`, invoked via `fleet-sync`) so that when executed on workstation/dwm nodes (or any node with `~/.local/src/dwm-oomaya` or `~/.local/src/quickshell-oomaya`), it autonomously:
1. Fast-forwards both repositories from `origin/main`.
2. Compiles C cores and helper binaries.
3. Installs runtime scripts and QML configurations into user space (`$HOME/.local/bin`, `$HOME/.config/quickshell`).
4. Gracefully hot-reloads the active desktop shell (`dwm-shell-mode quickshell` / `dwm-shell-mode suckless`) without session crash.

---

### 2. Implementation Specification

Add the helper function `sync_workstation_desktops()` to `/home/rand/dotfiles/install.sh` and call it at the conclusion of `stage_reload()` (after Neovim pre-syncing).

#### Function Blueprint:
```bash
sync_workstation_desktops() {
  local dwm_dir="$HOME/.local/src/dwm-oomaya"
  local qs_dir="$HOME/.local/src/quickshell-oomaya"

  # Gatekeeper: only run if either repository exists or profile is workstation
  if [ ! -d "$dwm_dir" ] && [ ! -d "$qs_dir" ] && [[ "${PROFILE:-}" != "workstation" ]]; then
    return 0
  fi

  print_header "Stage 3.7: Synchronizing DWM & Quickshell Desktop Stack"

  # 1. Coordinate dwm-oomaya
  if [ -d "$dwm_dir/.git" ]; then
    print_step "Synchronizing dwm-oomaya repository..."
    if ! git -C "$dwm_dir" diff-index --quiet HEAD -- 2>/dev/null; then
      git -C "$dwm_dir" pull --rebase --autostash -q origin main 2>/dev/null || true
    else
      git -C "$dwm_dir" pull --rebase -q origin main 2>/dev/null || true
    fi

    if command -v make &>/dev/null && command -v gcc &>/dev/null; then
      print_step "Compiling dwm-oomaya sovereign core..."
      make -C "$dwm_dir" -s all 2>/dev/null || print_warn "dwm-oomaya build encountered warnings"
    fi

    mkdir -p "$HOME/.local/bin"
    for s in dwm-shell-mode dwm-status dwm-session-launch dwm-panel-settings dwm-lock dwm-system-health dwm-settings-theme; do
      if [ -f "$dwm_dir/scripts/$s" ]; then
        install -Dm755 "$dwm_dir/scripts/$s" "$HOME/.local/bin/$s"
      fi
    done
    [ -f "$dwm_dir/scripts/autostart.sh" ] && install -Dm755 "$dwm_dir/scripts/autostart.sh" "$HOME/.local/bin/dwm-autostart"
    print_success "dwm-oomaya binaries and lifecycle scripts deployed"
  fi

  # 2. Coordinate quickshell-oomaya
  if [ -d "$qs_dir/.git" ]; then
    print_step "Synchronizing quickshell-oomaya repository..."
    if ! git -C "$qs_dir" diff-index --quiet HEAD -- 2>/dev/null; then
      git -C "$qs_dir" pull --rebase --autostash -q origin main 2>/dev/null || true
    else
      git -C "$qs_dir" pull --rebase -q origin main 2>/dev/null || true
    fi

    if command -v make &>/dev/null; then
      print_step "Building Quickshell helpers & state binary..."
      make -C "$qs_dir" -s all 2>/dev/null || print_warn "quickshell helper build warnings"
      print_step "Deploying Quickshell QML configs and helper binaries..."
      make -C "$qs_dir" -s install 2>/dev/null || print_warn "quickshell install warnings"
      print_success "quickshell-oomaya deployed to ~/.config/quickshell and ~/.local/bin"
    fi
  fi

  # 3. Graceful Live Shell Mode Reload
  if pgrep -x "dwm" &>/dev/null && command -v dwm-shell-mode &>/dev/null; then
    local current_mode
    current_mode=$(dwm-shell-mode status 2>/dev/null | awk '/Configured Mode/ {print $4}' || echo "quickshell")
    [ -z "$current_mode" ] && current_mode="quickshell"
    print_step "Reloading active DWM shell in '$current_mode' mode..."
    DISPLAY="${DISPLAY:-:0}" dwm-shell-mode "$current_mode" 2>/dev/null || true
    print_success "DWM shell environment synchronized and live-reloaded"
  fi
}
```

---

### 3. Strict Coding Constraints & Safeguards
1. **Zero Hardcoded Literals**: Always use `$HOME`, `$DOTFILES_DIR`, and dynamic paths. Never hardcode `/home/rand` or explicit node names.
2. **Process-Aware File Replacement**: Always use `install -Dm755` rather than `cp` to prevent `ETXTBSY` text file busy errors on active binaries.
3. **Graceful Degradation**: Guard every compiler invocation (`make`, `gcc`). If missing (e.g. on a minimal server profile), issue a warning and continue without breaking the rest of `install.sh`.
4. **Shell Safety**: Comply strictly with `set -euo pipefail`. Use `|| true` on optional git and display probes.
5. **Session Preservation**: Do not kill dwm; only reload the sub-shell via `dwm-shell-mode`.

---

### 4. Verification Protocol
1. **Syntax Check**: Run `bash -n /home/rand/dotfiles/install.sh`.
2. **Empirical Local Test**: Execute `/home/rand/dotfiles/install.sh --sync` on `mint-vm`.
3. **Assertion Checklist**:
   - `dwm-shell-mode status` confirms `quickshell` is RUNNING, Dunst is STOPPED.
   - Scripts in `~/.local/bin/` (`dwm-shell-mode`, `dwm-quickshell-state-bin`) are updated.
   - All standard dotfiles stages (stow, reload, verify, cleanup) report exit code `0`.

---

### 5. Deliverable & Handoff to Tech Lead
When complete, present:
1. Exact diff snippet applied to `install.sh`.
2. Output of `bash -n install.sh` and the local test execution.
3. Submit for **Tech Lead (Gemini) Review** against the 5-vector audit before escalating to the user for final sign-off.
