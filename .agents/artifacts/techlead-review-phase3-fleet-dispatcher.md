# Tech Lead Review: Phase 3 — Tailscale Fleet Dispatcher (`fleet-sync --fleet`)

> **Reviewer**: Gemini 2.5 Pro (Tech Lead / Systems Architect)  
> **Implementer**: Claude 3.5 Sonnet (Systems Coder)  
> **Sign-Off Authority**: Human Partner (User)  
> **Target**: `~/dotfiles/install.sh` (Patch: [`fleet-sync-phase3-install-sh.patch`](file:///home/rand/.gemini/antigravity-ide/brain/6adb259b-5a4d-4666-bdce-7c7728d36855/fleet-sync-phase3-install-sh.patch))  
> **Verdict**: **APPROVED (Ready for Human Sign-Off & Smoke Test)**  

---

## 1. Executive Summary

Sonnet's implementation of the Phase 3 Tailscale Fleet Dispatcher in `dotfiles/install.sh` faithfully executes all requirements and human amendments approved in [`tailscale-fleet-dispatcher-design.md`](file:///home/rand/.gemini/antigravity-ide/brain/6adb259b-5a4d-4666-bdce-7c7728d36855/tailscale-fleet-dispatcher-design.md).
The implementation was rigorously verified using a synthetic offline test harness covering canary aborts, sequential execution, parallel dispatch, and single-node targeting, along with live SSH quoting validation against `fedora44-vm` and real-mesh dry-run testing.

---

## 2. 5-Vector Adversarial Audit Matrix

| Vector | Requirement | Audit Result | Grade |
| :--- | :--- | :--- | :--- |
| **1. Zero Hardcoded Literals** | Dynamic resolution of node IPs, hosts, and paths | 100% compliant. Self IP is detected via `tailscale ip -4`, hostname via `hostname -s`, logs in `$XDG_STATE_HOME`. No hardcoded usernames, IPs, or node names. | **PASS** |
| **2. Command Injection & Quoting** | Safe remote subshell execution with session env | SSH payload verified via live probe on `fedora44-vm`: `PATH` resolves `~/.local/bin/fleet-sync`, `DISPLAY=:0`, `XDG=/run/user/1000`. No unquoted string interpolations. | **PASS** |
| **3. Error Boundaries & Failure Isolation** | Independent subshells; canary gate with warning tolerance | Canary gate enforces **`0 Failed`** while tolerating benign warnings. Multi-node sequential loop captures exit codes per node; failure of Node A never aborts Node B. | **PASS** |
| **4. XDG & Process-Aware Filesystem** | Persistent per-node logs and status exit tracking | Logs saved under `$HOME/.local/state/dotfiles/fleet-logs/<timestamp>/<node>.{log,rc}`. Clean separation of stdout/stderr and exit codes. | **PASS** |
| **5. Runtime Stability & KISS** | Sequential by default; non-destructive dry-run | `--dry-run` executes zero remote commands and creates zero log files. Sequential default spaces out executions, preventing SSH connection floods. | **PASS** |

---

## 3. Tech Lead Rulings on Implementer Deviations

Sonnet requested rulings on three specific implementation choices:

1. **Canary runs `install.sh --sync` only (relying on its internal `verify.sh` with resolved profile) rather than an explicit `verify.sh --profile workstation`**:
   - **Ruling: APPROVED (Superior Implementation)**. Running `install.sh --sync` automatically discovers and validates the host's actual profile (`omarchy` or `workstation`). Hardcoding `--profile workstation` would have broken dispatcher execution from Omarchy nodes (e.g. `omarchy-gram`).
2. **Node discovery via `tailscale status` text parsing without `jq`**:
   - **Ruling: APPROVED for v1**. Removing hard external dependencies adheres to the suckless/POSIX KISS philosophy. The awk pattern `NF >= 4 && $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/` reliably extracts peers.
3. **Strict Validation Rule: rc=0 with missing verification summary is classified as `FAIL`**:
   - **Ruling: APPROVED**. If a remote script exits early with code 0 before completing its verification suite, treating it as incomplete/failed prevents silent false-positive rollouts.

---

## 4. Verification Evidence & Warning Audit

### 4.1 Test Harness Results (Offline Simulation)
Recorded in [`harness_run_20261021.log`](file:///home/rand/.gemini/antigravity-ide/brain/6adb259b-5a4d-4666-bdce-7c7728d36855/logs/fleet-harness/harness_run_20261021.log):
- **Scenario A (Canary Failure)**: Simulated 2 failed checks on canary $\rightarrow$ Rollout immediately aborted with **`rc=2` and 0 SSH calls** (zero remote mutation).
- **Scenario B (Sequential with Mixed Results)**: Canary with 1 warning passed $\rightarrow$ Dispatched sequentially (calls spaced $\ge 1$s) across 4 nodes. `omarchy-vm` (timeout rc=255) and `peppermint-vm` (2 failed checks) failed, while `omarchy-gram` and `fedora44-vm` succeeded. All 4 nodes were attempted without aborting the sequence.
- **Scenario C (Parallel)**: All 4 calls dispatched within 2ms.
- **Scenario D (Node Filtering)**: `--nodes fedora44-vm` dispatched exactly 1 SSH call and returned `rc=0`.

### 4.2 Dry-Run & Live Mesh Verification
Recorded in [`dryrun_mint-vm_20261021.log`](file:///home/rand/.gemini/antigravity-ide/brain/6adb259b-5a4d-4666-bdce-7c7728d36855/logs/fleet-harness/dryrun_mint-vm_20261021.log):
```text
==> FLEET PREVIEW (DRY-RUN) - no commands executed, no logs written
  Node             Tailscale IP     State          RTT      Planned Action
  ----------------------------------------------------------------------------------------
  mint-vm          100.118.69.27    SELF           -        CANARY (local): install.sh --sync, gate: 0 Failed
  fedora44-vm      100.101.243.54   ONLINE         1ms      after canary: ssh -> fleet-sync (sequential)
  muse-1           100.69.212.28    SKIP-NONLINUX  -        [SKIPPED: non-Linux (unknown)]
  muse             100.106.200.118  OFFLINE        -        [SKIPPED: offline]
  omarchy-gram     100.82.99.66     ONLINE         3ms      after canary: ssh -> fleet-sync (sequential)
  omarchy-vm       100.124.231.48   ONLINE         1ms      after canary: ssh -> fleet-sync (sequential)
  peppermint-vm    100.126.37.73    ONLINE         1ms      after canary: ssh -> fleet-sync (sequential)
  win11-pc         100.126.57.34    SKIP-NONLINUX  -        [SKIPPED: non-Linux (windows)]
```

### 4.3 Warnings Audit
During the harness simulation, warnings were surfaced verbatim in the final summary:
- `[mint-vm] [WARN] omarchy-ctl operational in DEGRADED fallback mode`: Surfaced verbatim.
- `[fedora44-vm] [WARN] omarchy-ctl operational in DEGRADED fallback mode`: Surfaced verbatim.
- Zero warnings were hidden or presented as bare numbers.

---

## 5. Recommendation to Human Partner

The patch [`fleet-sync-phase3-install-sh.patch`](file:///home/rand/.gemini/antigravity-ide/brain/6adb259b-5a4d-4666-bdce-7c7728d36855/fleet-sync-phase3-install-sh.patch) is **technically sound, fully verified, and ready for application**.

### Recommended Application & Live Smoke Test
```bash
# 1. Apply the patch to dotfiles
cd ~/dotfiles
git apply ~/.gemini/antigravity-ide/brain/6adb259b-5a4d-4666-bdce-7c7728d36855/fleet-sync-phase3-install-sh.patch

# 2. Syntax check & Dry-run verification
bash -n install.sh && ./install.sh --fleet --dry-run

# 3. Controlled Live Smoke Test (Local Canary + fedora44-vm only)
./install.sh --fleet --nodes fedora44-vm
```
