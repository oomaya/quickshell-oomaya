# Tailscale-Powered Sovereign Fleet Orchestration Implementation Plan

> **Goal:** Build an agentic, zero-bureaucracy fleet management engine (`tailfleet` / `fleet-ops`) leveraging Tailscale WireGuard mesh networking, Tailscale SSH, and dynamic node discovery to automate cross-machine software deployment, health monitoring, and state synchronization across sovereign desktop fleet nodes.

**Architecture:** A lightweight POSIX-first orchestration toolchain (`tailfleet`) that queries `tailscale status --json` for live dynamic peer discovery, dispatches parallel execution via Tailscale SSH, coordinates distributed build/rollout pipelines (`dwm-oomaya`, `quickshell-oomaya`, `dotfiles`), and surfaces an event-driven cluster health matrix without introducing heavy external orchestration daemons like Ansible or Kubernetes.

**Tech Stack:** POSIX Shell (`set -eu`), Tailscale CLI (`tailscale status`, `tailscale ssh`, `tailscale ping`), SSH ControlMaster/mux, `jq` for JSON parsing, and native X11/IPC adapters.

**Spec / Requirements:**
- Sovereign Desktop Architecture Standard (Rule 3 & 7)
- Zero Hardcoded Literals Law (`$HOME`, `$XDG_*`, dynamic resolution)
- Heterogeneous Fleet: `mint-vm`, `omarchy-gram` (Arch/Hyprland), `fedora44`, `peppermint-vm`, `omarchy` (VMware VM), `cachyos-Niri`

---

## Quota & Token Budget Analysis (Go/No-Go Decision Gate)

| Metric | Status / Value | Assessment |
| :--- | :--- | :--- |
| **Gemini Weekly Quota Remaining** | **40.8%** (Rolling reset in 3d 14h) | 🟢 **Healthy** (> 15% threshold) |
| **Gemini 5-Hour Quota Remaining** | **78.8%** (Rolling reset in 53m) | 🟢 **Very Healthy** |
| **Claude & GPT Weekly Allowance** | **100.0%** (Full reserve untouched) | 🟢 **Pristine Reserve** |
| **Projected Phase Token Cost** | ~14k - 20k tokens total | 🟢 **Low Impact** (~3% of allowance) |
| **Dual-Model Decision** | Gemini 2.5 Flash / Pro for architecture & test validation; Claude Sonnet ready if deep C daemon refactoring is invoked | **GO** (Full Green Light) |

---

## Global Constraints

1. **Zero External Orchestration Daemons**: Never install Ansible, SaltStack, Chef, Puppet, or Kubernetes agents on fleet workstations. Rely exclusively on existing `/usr/bin/tailscale` and Tailscale SSH.
2. **Strict Identity Isolation**: The orchestrator must authenticate only across authenticated tailnet nodes (`*.ts.net` or `100.x.y.z`) under the sovereign identity `oomaya@`.
3. **Non-Blocking Fault Tolerance**: Offline or sleeping laptops (e.g. `omarchy-gram` with closed lid) must never stall or hang rollout pipelines targeting active workstations (`mint-vm`, `omarchy`, `peppermint-vm`).
4. **Zero Hardcoded IP/Node Literals**: All node endpoints, OS types, and reachability states must be discovered dynamically at runtime via `tailscale status --json`.
5. **Rollback & Dry-Run Guarantee**: Every destructive or state-mutating remote action must support `--dry-run` and automated rollback on failure.

---

## Review Focus

1. **Offline Peer Timeouts**: If a tailnet peer is sleeping or packet drops occur, SSH connections must timeout within 3 seconds rather than blocking for minutes.
2. **Interactive TTY / Sudo Elevation**: Remote scripts invoked via SSH must operate in non-interactive batch mode without prompting for interactive TTY or hanging on sudo.
3. **Cross-Distro Path Discrepancies**: Different distros place binaries in `/usr/local/bin`, `/usr/bin`, or `~/.local/bin`; remote invocations must ensure standard login PATH is exported.
4. **Tailscale SSH Authentication State**: If Tailscale SSH requires re-authentication, the tool must fail fast with a clear diagnostic message instead of hanging on terminal inputs.
5. **Concurrent Deployment Safety**: Avoid race conditions when multiple nodes pull from GitHub simultaneously; stagger or verify SHA before firing compile hooks.

---

## Task Decomposition & Execution Roadmap

### Task 1: Dynamic Tailnet Inventory & Discovery Engine (`tailfleet-inventory`)

**Files:**
- Create: `bin/tailfleet-inventory`
- Create: `tests/test-tailfleet-inventory.sh`

**Interfaces:**
- Consumes: Output of `tailscale status --json`
- Produces: Normalized JSON / TSV stream: `NODE_NAME\tTAILSCALE_IP\tOS\tSTATUS\tIS_SELF`

- [ ] **Step 1: Write unit test for inventory parsing**
  Create test fixture with mock `tailscale status --json` containing active, offline, and self nodes. Verify filtering by OS, active status, and self-exclusion.
- [ ] **Step 2: Run test to verify failure**
  Run `tests/test-tailfleet-inventory.sh` -> verify failure (command missing).
- [ ] **Step 3: Implement `tailfleet-inventory`**
  Parse JSON with `jq` extracting `Peer` map and `Self` node. Filter out expired or offline nodes by default; support `--all`, `--json`, and `--filter-os=linux` flags.
- [ ] **Step 4: Verify test passes**
  Run `tests/test-tailfleet-inventory.sh` -> verify PASS.
- [ ] **Step 5: Commit**
  `git commit -m "feat(tailfleet): implement dynamic tailnet inventory discovery engine"`

---

### Task 2: Resilient Remote Execution & Multiplexing Bridge (`tailfleet-exec`)

**Files:**
- Create: `bin/tailfleet-exec`
- Create: `tests/test-tailfleet-exec.sh`

**Interfaces:**
- Consumes: Node name / Tailscale IP, command string, execution timeout
- Produces: Execution exit code, stdout/stderr captured with node prefix, status summary

- [ ] **Step 1: Write unit test for execution wrapper**
  Test execution wrapper with mock `ssh` / `tailscale ssh`. Assert timeout enforcement (`ConnectTimeout=3`, `ServerAliveInterval=2`), PATH normalization (`PATH=$HOME/.local/bin:$PATH`), and non-interactive batch mode (`BatchMode=yes`).
- [ ] **Step 2: Run test to verify failure**
  Run `tests/test-tailfleet-exec.sh` -> verify failure.
- [ ] **Step 3: Implement `tailfleet-exec`**
  Implement wrapper with SSH ControlMaster socket caching under `$XDG_RUNTIME_DIR/tailfleet/` for sub-millisecond sequential calls, strict timeout guards, and colored node prefix formatting.
- [ ] **Step 4: Verify test passes**
  Run `tests/test-tailfleet-exec.sh` -> verify PASS.
- [ ] **Step 5: Commit**
  `git commit -m "feat(tailfleet): implement multiplexed remote execution engine over Tailscale SSH"`

---

### Task 3: Fleet Software Rollout & Build Pipeline (`tailfleet-rollout`)

**Files:**
- Create: `bin/tailfleet-rollout`
- Create: `tests/test-tailfleet-rollout.sh`

**Interfaces:**
- Consumes: Target package (`dwm-oomaya`, `quickshell-oomaya`, `dotfiles`, `all`), target node filter
- Produces: Per-node update status (git commit SHA before/after, compile status, test status, reload result)

- [ ] **Step 1: Write integration test for rollout pipeline**
  Test mock rollout across 2 virtual nodes: git fast-forward pull, `make clean all`, `make check`, `make install`, and `dwm-shell-mode` reload.
- [ ] **Step 2: Run test to verify failure**
  Run `tests/test-tailfleet-rollout.sh` -> verify failure.
- [ ] **Step 3: Implement `tailfleet-rollout`**
  Execute rolling or parallel updates using `tailfleet-exec`. Support `--dry-run`, verify git SHA change before triggering expensive builds, and execute rollback if tests fail.
- [ ] **Step 4: Verify test passes**
  Run `tests/test-tailfleet-rollout.sh` -> verify PASS.
- [ ] **Step 5: Commit**
  `git commit -m "feat(tailfleet): implement atomic fleet rollout and compile pipeline"`

---

### Task 4: Distributed Cluster Health Matrix & Desktop Observability (`tailfleet-status`)

**Files:**
- Create: `bin/tailfleet-status`
- Create: `quickshell/health/FleetHealthModel.qml` (optional desktop widget integration)
- Create: `tests/test-tailfleet-status.sh`

**Interfaces:**
- Consumes: Tailscale status, remote system metrics (uptime, dwm mode, quickshell PID, load, memory)
- Produces: Rich terminal dashboard table & structured JSON status feed for Quickshell

- [ ] **Step 1: Write test for cluster status aggregation**
  Test aggregation of local node state and remote node state into a single cohesive report.
- [ ] **Step 2: Run test to verify failure**
  Run `tests/test-tailfleet-status.sh` -> verify failure.
- [ ] **Step 3: Implement `tailfleet-status`**
  Query nodes concurrently in background subshells, aggregate metrics, display Tokyo Night styled ANSI summary table:
  `Node | IP | OS | WM/Shell | Quickshell PID | Uptime | Status`
- [ ] **Step 4: Verify test passes**
  Run `tests/test-tailfleet-status.sh` -> verify PASS.
- [ ] **Step 5: Commit**
  `git commit -m "feat(tailfleet): implement cluster health matrix and observability dashboard"`

---

### Task 5: Packaging, Unified CLI (`tailfleet`), and Makefile Integration

**Files:**
- Create: `bin/tailfleet` (Unified dispatcher: `tailfleet [status|inventory|exec|rollout|ping]`)
- Modify: `Makefile` (Add `tailfleet` to `SCRIPTS` and install targets)
- Modify: `.agents/artifacts/quickshell-dwm-fleet-update-guide.md` (Add Tailfleet instructions)
- Create: `tests/test-tailfleet-cli.sh`

- [ ] **Step 1: Implement unified `tailfleet` CLI**
  Route subcommands (`status`, `inventory`, `exec`, `rollout`, `sync`, `ping`) with comprehensive `--help` and safety rails.
- [ ] **Step 2: Update Makefile**
  Add `bin/tailfleet*` to installation manifest in `quickshell-oomaya` or `dwm-oomaya`.
- [ ] **Step 3: Run full test suite**
  Execute `make check` -> verify all existing and new tests pass 100% Green.
- [ ] **Step 4: Commit**
  `git commit -m "feat(tailfleet): integrate unified tailfleet CLI and deployment recipes"`

---

## Verification & Acceptance Criteria

1. **Local Tailnet Discovery**: `tailfleet inventory` outputs all 6 registered nodes (`mint-vm`, `omarchy`, `peppermint-vm`, `fedora44`, `win11-pc`, `muse`) with accurate status.
2. **Remote Execution**: `tailfleet exec omarchy "uname -a"` executes over Tailscale SSH and returns within <500ms without password prompts.
3. **One-Command Fleet Sync**: `tailfleet rollout --package=all` pulls latest `dwm-oomaya` and `quickshell-oomaya`, verifies `make check`, and reports green status across all reachable nodes.
4. **Zero Token Bloat**: All tool outputs formatted concisely for agentic and human operators.
