# Phase 3 Implementer Report — `fleet-sync --fleet` dispatcher

**Status: PATCH READY, NOT APPLIED, NO LIVE ROLLOUT PERFORMED.**
Writes to `~/dotfiles/install.sh` are policy-blocked (same as Phase 1), so the change is a patch.

- Patch: [fleet-sync-phase3-install-sh.patch](file:///home/rand/.gemini/antigravity-ide/brain/6adb259b-5a4d-4666-bdce-7c7728d36855/fleet-sync-phase3-install-sh.patch) (~268 added lines, 1 file; `fleet-sync` wrapper unchanged)
- Full modified copy: `scratch/p3.new`
- Evidence dir: `logs/fleet-harness/` (harness script + 3 logs, mirrored to `.agents/artifacts/logs/fleet-harness/`)

## Verification actually performed (reproducible)
| Check | Result | Evidence |
|---|---|---|
| `bash -n` | OK | — |
| `shellcheck -S warning` on new code | 0 findings (2 found, fixed) | — |
| `git apply --check` on current dotfiles HEAD | OK | — |
| `--fleet --dry-run` on mint-vm (real `tailscale status` + RTT) | OK, no logs dir created | `dryrun_mint-vm_20261021.log` |
| Arg orders via existing wrapper (`--sync --fleet`, `--fleet --sync -n`, ...) | all resolve to fleet mode | harness session |
| A: canary with 2 Failed | **rc=2, 0 ssh calls** (zero remote mutation) | `harness_run_20261021.log` |
| B: canary 0 Failed + 1 warning, sequential, mixed node results | rc=1, 4/4 nodes attempted despite omarchy-vm rc=255 and peppermint-vm 2 Failed; calls spaced ≥1s (sequential) | same |
| C: parallel | 4 calls within 2 ms; same outcome | same |
| D: `--nodes fedora44-vm` | rc=0, exactly 1 ssh call, others `EXCLUDED` | same |
| Remote command quoting, real node (read-only payload) | fedora44-vm: rc=0, `PATH` resolves `~/.local/bin/fleet-sync`, `DISPLAY=:0`, `XDG=/run/user/1000` | `remote_quote_probe_fedora44_20261021.log` |

## NOT verified (do not read the above as end-to-end proof)
- **No real `fleet-sync --fleet` live run.** ssh was stubbed in B/C/D and local install.sh was faked in A–D. The real canary path (`install.sh --sync` as child, verify summary parsing from real output) is covered only by the Phase 1/2 logs' summary-line format, not by a dispatcher run.
- Remote nodes that still have the *old* `install.sh` (no Stage 3.7) simply run their own `fleet-sync`; untested on omarchy-gram/omarchy-vm/peppermint-vm.
- `--canary <remote-node>` path is implemented but unexercised (only reaches the "not online" guard by inspection).

## Design amendments honored
- Canary gate = **0 Failed** (also FAIL on rc≠0 or missing summary); warnings never block and are listed **verbatim** per node in the summary (not just a count).
- Sequential default, `--parallel` opt-in; per-node failure isolation; per-node logs in `${XDG_STATE_HOME:-~/.local/state}/dotfiles/fleet-logs/<ts>/<node>.{log,rc}`; `--dry-run`; rollback out of scope (comment in code).

## Deviations from the work order (reviewer, please rule)
1. Canary runs `install.sh --sync` only (its Stage 4 already runs `verify.sh` with the node's *resolved* profile) instead of a second `verify.sh --profile workstation` — avoids hardcoding the profile (would be wrong on an Omarchy canary).
2. Node discovery parses `tailscale status` text (no jq dependency); online/non-Linux/offline classified from it. Fragile if Tailscale changes output format (open item).
3. `fleet-sync` wrapper not modified: existing `--sync` is made non-overriding when `--fleet` is present.
4. Remote command additionally prepends `$HOME/.local/bin` to `PATH` and uses `ssh -n`.

## Open points for Tech Lead
- Status counting: a passing canary is counted in "passed/with warnings" totals.
- Dry-run RTT uses `tailscale ping` (5s timeout) so it contacts peers; it does not execute anything on them.
- A node with rc=0 but no summary is treated FAIL ("no verification summary") — stricter than before; intended.

## Apply & test (user action)
```sh
cd ~/dotfiles
git apply ~/.gemini/antigravity-ide/brain/6adb259b-5a4d-4666-bdce-7c7728d36855/fleet-sync-phase3-install-sh.patch
bash -n install.sh && fleet-sync --fleet --dry-run
# live canary-only smoke (touches only fedora44-vm, already verified in Phase 2):
fleet-sync --fleet --nodes fedora44-vm
```
Run the live smoke yourself or tell me to; I did not do it unprompted. Commit only `install.sh`.
