# Task Packet 003 — QuickShell QML State Bridge & Action Modernization

**Status:** `ready`  
**Branch:** `packet/003-quickshell-qml-bridge-integration`  
**Author (architect):** dwm-oomaya Tech Lead Pair (Antigravity Architect)  
**Date:** 2026-11-05 KST  

---

### Objective

Modernize `quickshell-oomaya` to seamlessly communicate with `omarchy-ctl` for universal desktop state streaming and action dispatching, eliminating hardcoded X11 dependencies (`xdotool`, `xprop`) and completing **Gate 2** of the QuickShell Cross-WM Quad-Desktop integration.

---

### Repo Context

- Repo root: `/home/rand/.local/src/quickshell-oomaya`
- Files to modify:
  - `bin/dwm-quickshell-state` (POSIX sh state wrapper)
  - `quickshell/state/DwmState.qml` (Universal desktop state & action coordinator)
  - `Makefile` (Deployment and script installer)
- Target deployment destination:
  - `~/.config/quickshell/`
  - `~/.local/bin/`

---

### Architectural Invariants & Decisions

1. **First-Class `omarchy-ctl` Delegation**:
   - In `bin/dwm-quickshell-state`:
     - If `omarchy-ctl` is in `$PATH`, delegate directly to `exec omarchy-ctl "$@"`.
     - `omarchy-ctl state`, `omarchy-ctl watch`, `omarchy-ctl switch` (via `view`/`workspace`), and `omarchy-ctl focus` are already implemented and live-verified in C with sub-millisecond latencies.
     - Keep the legacy fallback chain (`dwm-quickshell-state-bin` / `xprop`) for resilience when running without `omarchy-ctl`.
2. **Action Dispatch Modernization in `DwmState.qml`**:
   - `switchWorkspace(index)`:
     `command: ["omarchy-ctl", "workspace", (index + 1).toString()]`
   - `focusWindow(windowId)`:
     `command: ["omarchy-ctl", "focus", windowId]`
   - `cycleLayout(direction)`:
     Replace fragile X11-only `xdotool` invocation with:
     `command: ["omarchy-ctl", "layout", (direction > 0 ? "next" : "prev")]`
   - Initial process definitions (`switchWorkspaceProcess`, `focusWindowProcess`, `cycleLayoutProcess`) must mirror these commands.
3. **Legacy Compatibility Symlink**:
   - In `Makefile` (under the `install` target), create a fallback symlink `$(BIN_DIR)/oomaya-ctl -> omarchy-ctl` if `omarchy-ctl` exists, ensuring no legacy scripts break.
4. **Preserve Clean Aesthetics & 0 Regressions**:
   - All tests in `tests/test-quickshell*.sh` must pass or remain valid.

---

### Scope & Tasks

1. **Edit `bin/dwm-quickshell-state`**:
   - Add delegation at the top of the script:
     ```sh
     if [ -z "${DWM_TEST_MONITOR_DESKTOPS:-}" ] && [ -z "${DWM_TEST_FULLSCREEN_MONITORS:-}" ] && [ -z "${DWM_TEST_SELECTED_MONITOR:-}" ]; then
         if command -v omarchy-ctl >/dev/null 2>&1; then
             exec omarchy-ctl "$@"
         fi
         if command -v dwm-quickshell-state-bin >/dev/null 2>&1; then
             exec dwm-quickshell-state-bin "$@"
         fi
     fi
     ```
   - Ensure `switch` argument translates to `workspace` when passed to `omarchy-ctl` if needed (or `omarchy-ctl view`).
2. **Edit `quickshell/state/DwmState.qml`**:
   - Replace all `oomaya-ctl` string references with `omarchy-ctl`.
   - In `cycleLayout(direction)`:
     ```javascript
     function cycleLayout(direction) {
         cycleLayoutProcess.command = ["omarchy-ctl", "layout", direction > 0 ? "next" : "prev"];
         cycleLayoutProcess.running = true;
     }
     ```
   - In `cycleLayoutProcess`:
     ```qml
     Process {
         id: cycleLayoutProcess
         command: ["omarchy-ctl", "layout", "next"]
         running: false
     }
     ```
3. **Edit `Makefile`**:
   - Under `install:` target:
     ```makefile
     @if command -v omarchy-ctl >/dev/null 2>&1 || [ -x "$(BIN_DIR)/omarchy-ctl" ]; then \
         ln -sf omarchy-ctl "$(BIN_DIR)/oomaya-ctl"; \
     fi
     ```
4. **Run Tests & Verify**:
   - `make install`
   - Verify `dwm-quickshell-state state`
   - Verify `tests/test-quickshell-controls.sh` (or other suite tests)

---

### Builder Handover Instructions

1. Work on branch `packet/003-quickshell-qml-bridge-integration`.
2. Implement the changes in `bin/dwm-quickshell-state`, `quickshell/state/DwmState.qml`, and `Makefile`.
3. Run `make install` and test `dwm-quickshell-state state`.
4. Leave notes with test output in your completion report.
5. Notify Tech Lead for Gate 2 review.
