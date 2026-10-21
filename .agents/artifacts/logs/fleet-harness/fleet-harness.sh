#!/usr/bin/env bash
# Offline harness for the fleet dispatcher: real `tailscale status` discovery, STUBBED ssh and
# STUBBED local install.sh. No remote node is contacted or modified.
set -u
SRC="${1:?path to modified install.sh}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/dot"

# --- function block under test (from "Fleet Dispatcher" header to "Main Dispatcher" header)
start=$(grep -n '^# Fleet Dispatcher' "$SRC" | cut -d: -f1); start=$((start - 1))
end=$(grep -n '^# Main Dispatcher' "$SRC" | cut -d: -f1); end=$((end - 2))
sed -n "${start},${end}p" "$SRC" > "$T/fns.sh"

print_header() { printf '\n==> %s\n' "$1"; }
print_step()   { printf '  • %s\n' "$1"; }
print_success(){ printf '  ✓ %s\n' "$1"; }
print_warn()   { printf '  ! %s\n' "$1"; }
print_error()  { printf '  ✗ %s\n' "$1"; }
# shellcheck disable=SC1091
source "$T/fns.sh"
export DOTFILES_DIR="$T/dot" XDG_STATE_HOME="$T/state"

# --- stub ssh: behaviour keyed by destination IP
cat > "$T/bin/ssh" <<'EOF'
#!/usr/bin/env bash
ip=""; for a in "$@"; do [[ "$a" =~ ^100\. ]] && ip="$a"; done
echo "$(date +%s.%N) $ip" >> "$STUB_CALLS"
case "$ip" in
  100.101.243.54) sleep 1; printf '  ! [WARN] omarchy-ctl operational in DEGRADED fallback mode\nVerification Summary: 84 Passed, 0 Failed, 1 Warnings\n'; exit 0 ;;  # fedora44-vm
  100.124.231.48) echo "ssh: connect to host timed out" >&2; exit 255 ;;                                                                                        # omarchy-vm
  100.126.37.73)  printf '  ✗ [FAIL] something broke\nVerification Summary: 80 Passed, 2 Failed, 0 Warnings\n'; exit 0 ;;                                                  # peppermint-vm
  *)              printf 'Verification Summary: 85 Passed, 0 Failed, 0 Warnings\n'; exit 0 ;;                                                                       # omarchy-gram
esac
EOF
chmod +x "$T/bin/ssh"; export PATH="$T/bin:$PATH" STUB_CALLS="$T/calls"

fake_install() { # $1 = failed count, $2 = rc
  printf '#!/usr/bin/env bash\nprintf "  ! [WARN] omarchy-ctl operational in DEGRADED fallback mode\\nVerification Summary: 83 Passed, %s Failed, 1 Warnings\\n"\nexit %s\n' "$1" "$2" > "$T/dot/install.sh"
  chmod +x "$T/dot/install.sh"
}
run() { : > "$T/calls"; DRY_RUN=0 PARALLEL=${PARALLEL:-0} CANARY_TARGET=local NODES_FILTER="${NODES_FILTER:-}" dispatch_fleet; echo "RC=$?"; echo "ssh calls: $(wc -l < "$T/calls")"; }

echo "################ A: canary has 2 Failed -> must abort (rc=2) with ZERO ssh calls"
fake_install 2 1; PARALLEL=0 run

echo; echo "################ B: canary 0 Failed + 1 warning (tolerated), SEQUENTIAL, mixed node results (rc=1 expected, all 4 attempted)"
fake_install 0 0; PARALLEL=0 run; echo "--- call order/timestamps:"; cat "$T/calls"

echo; echo "################ C: same, PARALLEL"
fake_install 0 0; PARALLEL=1 run; echo "--- call timestamps:"; cat "$T/calls"

echo; echo "################ D: --nodes fedora44-vm only (rc=0 expected, 1 ssh call)"
fake_install 0 0; PARALLEL=0 NODES_FILTER=fedora44-vm run

echo; echo "################ E: per-node logs retained"
ls -1 "$T"/state/dotfiles/fleet-logs/*/ | sort | uniq -c | sort -rn | head -20
mkdir -p "${KEEP:-/dev/null}" 2>/dev/null; [[ -n "${KEEP:-}" ]] && cp -r "$T/state/dotfiles/fleet-logs" "$KEEP/" || true
