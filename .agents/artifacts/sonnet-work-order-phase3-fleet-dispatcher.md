# Work Order for Implementer (Claude 3.5 Sonnet)
## Task: Phase 3 — Implement Tailscale Fleet Dispatcher (`fleet-sync --fleet`)

> **Assignee**: Claude 3.5 Sonnet (Implementer / Systems Coder)  
> **Reviewer**: Gemini 2.5 Pro (Tech Lead / Systems Architect)  
> **Approver / Sign-Off**: Human Partner (User)  
> **Reference Design**: [`tailscale-fleet-dispatcher-design.md`](file:///home/rand/.gemini/antigravity-ide/brain/6adb259b-5a4d-4666-bdce-7c7728d36855/tailscale-fleet-dispatcher-design.md)  
> **Target Files**: `/home/rand/dotfiles/install.sh`, `/home/rand/dotfiles/antigravity/.local/bin/fleet-sync`  
> **Safety Level**: High (Multi-Node Network Orchestrator)  

---

### 1. Architectural Mission
Implement the remote Tailscale Fleet Dispatcher CLI mode (`fleet-sync --fleet`), transforming `fleet-sync` into a centralized control tower that can preview, canary-validate, and dispatch updates across the heterogeneous fleet over Tailscale WireGuard + SSH.

---

### 2. Approved Design Specifications & Amendments

1. **Canary Gate Criterion**:
   - Must run local canary (`mint-vm`) first.
   - Gate condition: **`0 Failed`** (`exit code == 0` and zero failed verification checks).
   - **Tolerate Benign Warnings**: Do NOT block on warnings (e.g. `omarchy-ctl DEGRADED` on X11 is permanent benign). Surface warnings in the summary.
2. **Dispatch Concurrency**:
   - **Default: Sequential Dispatch** (`PARALLEL=0`). Nodes are processed one-by-one with clear console progress and timing.
   - **Opt-in: Parallel Dispatch** (`--parallel` flag).
3. **Dry-Run Mode (`--dry-run` / `-n`)**:
   - Probe Tailscale status via `tailscale status --json` (or `tailscale status`).
   - Ping online nodes (`tailscale ping -c 1 --timeout 1s <node>`).
   - Print structured target preview table. Zero remote commands executed.
4. **Per-Node Failure Isolation & Logging**:
   - Session log directory: `$HOME/.local/state/dotfiles/fleet-logs/<TIMESTAMP>/`.
   - Each node output captured into `<node>.log`.
   - One node failure never aborts other nodes in the sequence.
5. **Real Session Environment**:
   - Remote command invocation must pass login shell and graphical display context:
     ```bash
     ssh -o BatchMode=yes -o ConnectTimeout=5 "$node_ip" \
       "bash -l -c 'export DISPLAY=\${DISPLAY:-:0}; export XDG_RUNTIME_DIR=\${XDG_RUNTIME_DIR:-/run/user/\$(id -u)}; fleet-sync'" \
       > "$node_log" 2>&1
     ```
6. **v1 Scope Boundary**:
   - Automated rollback across nodes is explicitly **Out of Scope for v1**.

---

### 3. Implementation Steps

1. **Update `dotfiles/install.sh` CLI Parser**:
   - Add flags:
     - `--fleet`: sets `MODE="fleet"`
     - `--dry-run` / `-n`: sets `DRY_RUN=1`
     - `--parallel`: sets `PARALLEL=1` (defaults to `0`)
     - `--canary <node>`: sets `CANARY_TARGET="$2"` (defaults to `local`)
2. **Implement `dispatch_fleet()` Function in `install.sh`**:
   - Query online nodes dynamically using `tailscale status --json | jq ...` (fallback to `tailscale status` awk if jq unavailable).
   - Filter out `Self` node and non-Linux nodes (e.g. `OS == "windows"`).
   - Handle `--dry-run` early exit.
   - Execute Stage 1 Canary: `./install.sh --sync && ./verify.sh --profile workstation`.
   - Execute Stage 2 & 3: Iterate through target nodes sequentially (or parallel if requested), recording exit code and elapsed time.
   - Print final telemetry summary table.
3. **Update `dotfiles/antigravity/.local/bin/fleet-sync`**:
   - Ensure arguments are forwarded cleanly:
     ```bash
     #!/usr/bin/env bash
     set -euo pipefail
     DOTFILES_DIR="${DOTFILES_DIR:-$([ -d "$HOME/dotfiles" ] && echo "$HOME/dotfiles" || echo "$HOME/.dotfiles")}"
     if [[ "${1:-}" == "--fleet" ]] || [[ "${1:-}" == "--dry-run" ]] || [[ "${1:-}" == "-n" ]]; then
       exec "$DOTFILES_DIR/install.sh" "$@"
     fi
     exec "$DOTFILES_DIR/install.sh" --sync "$@"
     ```

---

### 4. Verification Protocol
1. **Syntax Check**: `bash -n /home/rand/dotfiles/install.sh`
2. **Dry-Run Test**: Run `fleet-sync --fleet --dry-run` on `mint-vm`. Confirm matrix displays `mint-vm (Canary)`, `fedora44-vm`, `omarchy-vm`, etc.
3. **Live Execution Test**: Run `fleet-sync --fleet` on `mint-vm`.
   - Confirm local canary executes first and passes.
   - Confirm sequential dispatch to `fedora44-vm`.
   - Confirm per-node logs generated under `~/.local/state/dotfiles/fleet-logs/<timestamp>/`.
   - Confirm final summary table displays accurately.

---

### 5. Handoff to Tech Lead
Deliver:
1. Unified patch or modified code.
2. Full test output of `fleet-sync --fleet --dry-run` and live rollout.
3. Log locations for Tech Lead review against the 5 audit vectors.
