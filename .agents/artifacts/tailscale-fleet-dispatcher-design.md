# One-Page Design: Tailscale Fleet Dispatcher (`fleet-sync --fleet`)

> **Author**: Antigravity Technical Lead & Systems Architect  
> **Status**: Proposed (Awaiting Human Partner Sign-off)  
> **Scope**: Remote coordination across Omarchy (Hyprland) and DWM/Quickshell nodes  
> **Prerequisites**: Phase 1 local engine (`install.sh`) complete & Phase 2 verified  

---

## 1. Architectural Philosophy & Core Tenets

1. **Canary-First Principle**: Never dispatch to remote nodes until the local canary node (`mint-vm`) verifies 100% green. If the canary fails, rollout immediately halts.
2. **Zero Blast Radius (Failure Isolation)**: Each remote node executes in an isolated worker thread. A network timeout or compile failure on Node A never interrupts Node B.
3. **Reproducible Per-Node Logs**: Every run writes raw stdout/stderr into dedicated, timestamped per-node files for auditability.
4. **Dry-Run Predictability**: An explicit `--dry-run` flag visualizes targets, online states, and commands without executing any mutations.

---

## 2. CLI Interface & Flag Specification

```text
Usage: fleet-sync [OPTIONS]

Options:
  --sync               Run local 5-stage synchronization pipeline (default)
  --fleet              Broadcast fleet synchronization across all online Tailscale nodes
  --dry-run, -n        (Used with --fleet) Preview target nodes and actions without execution
  --canary <node>      Override canary target (Default: local node / mint-vm)
  --nodes <n1,n2...>   Target specific subset of fleet nodes (Default: all online nodes)
```

---

## 3. End-to-End Execution Flow

```mermaid
flowchart TD
    A["fleet-sync --fleet [--dry-run]"] --> B{"--dry-run specified?"}
    B -- Yes --> C["🔍 Preview Mode:\nQuery tailscale status -> Probe pings -> Print target matrix -> Exit 0"]
    B -- No --> D["🐤 Stage 1: Local Canary Verification (mint-vm)"]
    D --> E{"Canary Passed?\n(verify.sh == 0)"}
    E -- Failed --> F["🛑 CANARY ABORT:\nLog canary failure -> Halt fleet rollout -> Zero remote mutation"]
    E -- Passed --> G["🌐 Stage 2: Discover Online Tailscale Nodes"]
    G --> H["🚀 Stage 3: Isolated Remote Dispatch (Parallel or Sequential)"]
    H --> I["🖥️ Node 1: fedora44-vm\n(tee to logs/fedora44.log)"]
    H --> J["💻 Node 2: omarchy-vm\n(tee to logs/omarchy-vm.log)"]
    H --> K["💻 Node 3: omarchy-gram\n(tee to logs/omarchy-gram.log)"]
    I --> L["📊 Stage 4: Fleet Telemetry Summary & Exit Code Resolution"]
    J --> L
    K --> L
```

---

## 4. Key Mechanism Specifications

### 4.1. Local Canary Gate (`mint-vm`)
Before initiating any remote SSH connection:
1. Run local `./install.sh --sync` and `./verify.sh --profile workstation`.
2. Assert zero broken symlinks and exit code `0`.
3. If canary check encounters errors, print `[CANARY FAILED]` and exit with status code `2`.

### 4.2. Dry-Run Mode (`--dry-run`)
When `--dry-run` is invoked:
1. Parse online nodes via `tailscale status --json` (ignoring offline/self).
2. Run single ping probe `tailscale ping -c 1 --timeout 1s <node>` to measure RTT.
3. Print a formatted matrix:
   ```text
   FLEET PREVIEW (DRY-RUN):
   Node             Tailscale IP     Status   RTT      Role/Profile    Planned Action
   ----------------------------------------------------------------------------------
   mint-vm (Local)  100.118.69.27    ONLINE   0.0ms    Canary (Local)  ./install.sh --sync
   fedora44-vm      100.101.243.54   ONLINE   1.2ms    Workstation     ssh -> fleet-sync
   omarchy-vm       100.124.231.48   ONLINE   1.4ms    Omarchy         ssh -> fleet-sync
   peppermint-vm    100.126.37.73    ONLINE   0.9ms    Workstation     ssh -> fleet-sync
   win11-pc         100.126.57.34    ONLINE   -        Windows         [SKIPPED (Non-Linux)]
   ```
4. Exits cleanly with zero remote writes.

### 4.3. Per-Node Failure Isolation & Logging
- **Log Destination**:
  `$HOME/.local/state/dotfiles/fleet-logs/<TIMESTAMP>/<NODE_NAME>.log`
  *(e.g., `~/.local/state/dotfiles/fleet-logs/20261021_140000/fedora44-vm.log`)*
- **Remote Execution Command**:
  ```bash
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$node_ip" \
    "bash -l -c 'export DISPLAY=\${DISPLAY:-:0}; export XDG_RUNTIME_DIR=\${XDG_RUNTIME_DIR:-/run/user/\$(id -u)}; fleet-sync'" \
    > "$log_file" 2>&1
  ```
- **Error Boundary**:
  Each node runs in a subshell block. If Node A fails (e.g. exit 1), `NODE_STATUS[fedora44-vm]="FAIL"` is recorded, but the dispatch loop immediately continues to Node B.

### 4.4. Telemetry Reporting Table
Upon completion of all online targets, a clean summary table is printed:
```text
================================================================================
  FLEET ROLLOUT SUMMARY [2026-10-21 14:05:22]
================================================================================
  Node             Status   Duration   Log Location
  ------------------------------------------------------------------------------
  mint-vm          PASS     4.2s       .../fleet-logs/20261021_140000/mint-vm.log
  fedora44-vm      PASS     8.1s       .../fleet-logs/20261021_140000/fedora44-vm.log
  omarchy-vm       PASS     6.4s       .../fleet-logs/20261021_140000/omarchy-vm.log
  peppermint-vm    WARN     7.2s       .../fleet-logs/20261021_140000/peppermint-vm.log
================================================================================
  Result: 3 Passed, 1 Warning, 0 Failed. All nodes isolated and archived.
```

---

## 5. Decision Gate for Human Partner Sign-Off

- **Sign-Off Required**:
  1. Approval of the **Canary-First** gate (mint-vm must be 100% green before remote rollout).
  2. Approval of the **`--dry-run`** matrix format.
  3. Approval of **per-node isolated logging** under `~/.local/state/dotfiles/fleet-logs/<timestamp>/`.
