#!/usr/bin/env bash
# End-to-end bootstrap test on a throwaway Multipass VM (ROADMAP Phase 1b).
#
#   dev/vm-test.sh <dev-env-file> [branch]
#
# <dev-env-file> holds DOPPLER_PROJECT, DOPPLER_CONFIG=dev and a dev-scoped
# DOPPLER_TOKEN. It is copied into the VM as ~/homelab/.env and never printed.
# [branch] defaults to the current branch; it must be pushed to GitHub.
#
# Options (env): VM_NAME (default homelab-dev-test), EXPECT_TS_NAME (default
# homelab-dev, i.e. TAILSCALE_HOSTNAME in Doppler dev), KEEP_VM=1 to leave the
# VM running afterwards, LOG_DIR (default ./vm-test-logs).
#
# The test: fresh VM → bootstrap → idempotent second run → host checks →
# restart-on-change. Cleanup always runs: tailscale logout (removes the
# ephemeral node), then the VM is deleted and purged.
set -euo pipefail

ENV_FILE=${1:?usage: dev/vm-test.sh <dev-env-file> [branch]}
BRANCH=${2:-$(git rev-parse --abbrev-ref HEAD)}
VM=${VM_NAME:-homelab-dev-test}
EXPECT_TS_NAME=${EXPECT_TS_NAME:-homelab-dev}
LOG_DIR=${LOG_DIR:-./vm-test-logs}
REPO_URL=https://github.com/tbeidlershenk/homelab.git

[ -r "$ENV_FILE" ] || { echo "Cannot read $ENV_FILE" >&2; exit 2; }
grep -qx 'DOPPLER_CONFIG=dev' "$ENV_FILE" \
    || { echo "Refusing: $ENV_FILE must contain DOPPLER_CONFIG=dev" >&2; exit 2; }
command -v multipass >/dev/null || { echo "multipass not found (sudo snap install multipass)" >&2; exit 2; }
if multipass info "$VM" >/dev/null 2>&1; then
    echo "A VM named $VM already exists; delete it or set VM_NAME." >&2; exit 2
fi
mkdir -p "$LOG_DIR"

cleanup() {
    if [ "${KEEP_VM:-}" = 1 ]; then echo "KEEP_VM=1: leaving $VM running."; return; fi
    echo "== Cleanup: tailscale logout, delete $VM"
    multipass exec "$VM" -- sudo tailscale logout >/dev/null 2>&1 || true
    multipass delete --purge "$VM" >/dev/null 2>&1 || true
}
trap cleanup EXIT

vm() { multipass exec "$VM" -- bash -lc "cd ~/homelab && $1"; }

failures=0
pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1"; failures=$((failures + 1)); }
# check <description> <command in VM> <extended regex the output must match>
check() {
    local out
    out=$(vm "$2" 2>&1 || true)
    if grep -Eq -- "$3" <<<"$out"; then pass "$1"; else fail "$1 (got: $(head -c 200 <<<"$out" | tr '\n' ' '))"; fi
}
# play <name>: run prepare/bootstrap, keep the log, echo the recap line
play() {
    local name=$1 cmd=$2
    vm "sudo $cmd" >"$LOG_DIR/$name.log" 2>&1 || true
    grep -E '^homelab +: ' "$LOG_DIR/$name.log" | tail -1 || true
}
recap_is() { # recap_is <recap line> <changed count>
    grep -Eq "changed=$2 .*failed=0 " <<<"$1"
}

echo "== Launching $VM (branch $BRANCH)"
multipass launch 24.04 --name "$VM" --cpus 2 --memory 3G --disk 15G
vm_home=/home/ubuntu/homelab
multipass exec "$VM" -- git clone -q -b "$BRANCH" "$REPO_URL" "$vm_home"
multipass transfer "$ENV_FILE" "$VM:$vm_home/.env"
multipass exec "$VM" -- chmod 600 "$vm_home/.env"
echo "  commit: $(vm 'git log --oneline -1')"

echo "== 1. Bootstrap from nothing"
r=$(play first-run ./bootstrap.sh); echo "  $r"
grep -Eq 'failed=0 ' <<<"$r" && pass "bootstrap completes" || fail "bootstrap completes"

echo "== 2. Idempotence (second run must change nothing)"
r=$(play second-run ./scripts/prepare.sh); echo "  $r"
if recap_is "$r" 0; then pass "second run changed=0"; else
    fail "second run changed=0"
    grep -B1 -E '^changed:' "$LOG_DIR/second-run.log" | sed 's/^/        /' || true
fi

echo "== 3. Host checks"
check "API health"            "curl -s localhost:5001/"                                    '"status": ?"ok"'
check "services active"       "systemctl is-active api tailscaled docker | sort -u | tr '\\n' ' '" '^active $'
check "cloudflared not running in dev" "systemctl is-active cloudflared"                   '^(inactive|unknown|failed)'
check ".env is 0600"          "sudo stat -c %a /etc/homelab/.env"                          '^600$'
check "tailscale state dir 0700" "sudo stat -c %a data/tailscale"                      '^700$'
check "Dockhand container up" "sudo docker ps --format '{{.Names}} {{.Status}}'"           '^dockhand Up'
check "Dockhand answers"      "curl -s -o /dev/null -w '%{http_code}' localhost:4000"      '^(200|30[0-9])$'
check "unknown task → 404"    "curl -s -o /dev/null -w '%{http_code}' localhost:5001/tasks/run/does-not-exist" '^404$'
check "traversal → 404"       "curl -s -o /dev/null -w '%{http_code}' 'localhost:5001/tasks/run/..%2Fx'"      '^404$'
check "deb822 repos"          "ls /etc/apt/sources.list.d/ | tr '\n' ' '"                  'docker\.sources.*tailscale\.sources|tailscale\.sources.*docker\.sources'
check "tailnet name has no -N suffix" \
    "tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"Self\"][\"DNSName\"])'" \
    "^${EXPECT_TS_NAME}\."
check "DNS works with Tailscale up" "getent hosts pkgs.tailscale.com"                      '[0-9a-f.:]+ +pkgs\.tailscale\.com'

echo "== 4. Restart-on-change"
vm "echo '# vm-test' >> api/server.py"
r=$(play change-run ./scripts/prepare.sh); echo "  $r"
if recap_is "$r" 2 && grep -q 'RUNNING HANDLER \[api : Restart api\]' "$LOG_DIR/change-run.log"; then
    pass "code change → source hash + API restart only"; else fail "code change → source hash + API restart only"; fi
vm "git checkout -q api/server.py"
play revert-run ./scripts/prepare.sh >/dev/null
r=$(play settle-run ./scripts/prepare.sh); echo "  $r"
recap_is "$r" 0 && pass "back to changed=0" || fail "back to changed=0"

echo
echo "Logs: $LOG_DIR/"
if [ "$failures" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "$failures CHECK(S) FAILED"; exit 1; fi
