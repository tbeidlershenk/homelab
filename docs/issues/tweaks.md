# Tweaks & Security

Small, self-contained fixes. Each one should fit in a single PR.

**Phase 0 status:** branch `phase0-security` (worktree `/home/tbeidlershenk/homelab-phase0`), not yet committed.

| Item | Status |
|---|---|
| S1 script-name validation / no `shell=True` | ✅ done on branch |
| S2 bind + auth | ⏸ deferred: a LAN device calls the API, so binding to tailnet + localhost would break it; you chose to skip token auth for now. Planned: a firewall rule allowing specific LAN sources (Ansible `base` role), plus auth in Phase 3. |
| S3 `.env` 0600 | ✅ done on branch (temp file at 0600 + atomic `mv`) |
| S4 PAT in gitconfig | ✅ done on branch (`prepare.sh` now runs `--unset-all user.token`) |
| S5 unpinned installers | → Phase 1 (Ansible) |
| S6 `eval` of secrets | ✅ done on branch (JSON + `shlex.quote`) |
| S7 SSH key upload | ✅ code done on branch. **Manual follow-up:** delete the `SSH_PRIVATE_KEY`, `SSH_USER` and `SSH_HOST` repo secrets; consider rotating the key |
| B4 `set -a` typo | ✅ done on branch |
| C2 error message | ✅ done on branch |

## Security

### S1. Script name from the URL is passed to a shell unchecked
- **Where:** `api/routes/tasks.py` — `run_task`, `run_task_unattended`
- **Problem:** `<script_name>` is joined into `scripts/<name>.sh` and run with `shell=True` (streaming route), without validation. Encoded `../` could reach scripts outside `scripts/`, and shell metacharacters in the path get interpreted. Exposure is limited because the API is only reachable over Tailscale (see S2).
- **Fix:** Reject names that don't match `^[A-Za-z0-9_-]+$`, resolve the path and confirm it is inside `scripts_dir` and exists, and run it as `["bash", path]` without `shell=True`. Optionally keep an explicit allowlist of callable scripts.

### S2. API listens on all interfaces with no authentication
- **Where:** `config/wrappers/api_start.sh` (`--bind 0.0.0.0:5001`)
- **Problem:** Anything that can reach port 5001 (LAN or Tailscale) can run any script, including `deploy`. Root execution makes this worse (see A3).
- **Fix:** Bind to the Tailscale IP, or firewall 5001 to the `tailscale0` interface. Add a shared bearer token checked in a `before_request` hook, and give it to CI as a GitHub secret.

### S3. `/etc/homelab/.env` is probably world-readable
- **Where:** `scripts/doppler-save.sh`
- **Problem:** `tee /etc/homelab/.env` creates the file with root's default umask, typically giving 0644, so every Doppler secret is readable by any local user.
- **Fix:** Add `install -m 600 /dev/null /etc/homelab/.env` before writing, or `chmod 600` after.

### S4. GitHub PAT stored in plaintext global git config
- **Where:** `scripts/prepare.sh` — `git config --global user.token $GITHUB_PAT`
- **Problem:** `user.token` isn't a key git uses; it just leaves the PAT in root's `~/.gitconfig`. `gh auth login` already stores credentials.
- **Fix:** Delete the line, and remove the existing value with `git config --global --unset user.token`.

### S5. Remote installers piped straight to `sh`
- **Where:** `scripts/install.sh` (Doppler, Filen, Docker, Tailscale), and cloudflared's `latest` `.deb`
- **Problem:** Nothing is pinned or checksummed, so CI and prod can install different versions.
- **Fix:** Use the vendors' apt repositories where they exist (Docker, Tailscale, Doppler and Cloudflare all publish them), or pin versions and verify checksums.

### S6. Downloaded secrets are `eval`ed in every script
- **Where:** `scripts/doppler-get.sh`
- **Problem:** `eval "$(doppler secrets download --format env | sed 's/^/export /')"` executes the secret values as shell code. Any value containing `$(...)`, backticks or an unbalanced quote runs as a command or breaks every script.
- **Fix:** Download with `--format docker` (plain `KEY=value`, no shell quoting) to a 0600 temp file, then load it with `set -a; source` after validating the keys. Better still, use `doppler run -- <cmd>`, which injects the variables without a shell round-trip.

### S7. The server's root SSH private key is uploaded to GitHub, but nothing uses it
- **Where:** `scripts/prepare.sh` — `gh secret set SSH_PRIVATE_KEY -b @"$SSH_PRIVATE_KEY"` (prod), along with `SSH_USER` / `SSH_HOST`
- **Problem:** `deploy.yml` never references these secrets, because it deploys over HTTP. A leaked Actions secret, or a malicious workflow change, would hand out root's private key, which is also the key registered on your GitHub account.
- **Fix:** Remove the three `gh secret set SSH_*` lines, delete the secrets from the repo, and consider rotating the key. Phase 2 of [architecture.md](architecture.md) also removes `TAILSCALE_CI_AUTHKEY`.

## Bugs

### B1. Wrong variable checked for `MACOS_MAC_ADDRESS`
- **Where:** `api/routes/otps.py:19`
- **Problem:** The second check tests `macos_hostname` again, so a missing MAC address isn't caught at startup and `wake(None)` fails at request time.
- **Fix:** `if macos_mac_address is None:`

### B2. `BASE_DIR` check crashes instead of printing its error
- **Where:** `api/routes/tasks.py:18`
- **Problem:** `os.path.exists(None)` raises `TypeError` before the friendly message prints.
- **Fix:** `if not base_dir or not os.path.isdir(base_dir):`

### B3. No timeouts on outbound requests in `/otps/get`
- **Where:** `api/routes/otps.py`
- **Problem:** If the Mac doesn't wake, `requests.get` can block a gevent worker indefinitely (gunicorn runs with `--timeout 0`).
- **Fix:** Pass `timeout=` to both calls, and retry `/caffeinate` a few times while the Mac boots instead of a fixed `sleep(1)`.

### B4. `set -a` used where `set +a` was meant
- **Where:** all three `config/wrappers/*_start.sh`
- **Problem:** The second `set -a` should be `set +a`. It's harmless because the scripts `exec` right after, but it's misleading.

## Cleanup

### C1. Comment says the wrong label name
- **Where:** `scripts/backup.sh` — the comment says `pause_on_backup`, but the code filters on `pause_for_backup=true`.

### C2. Misleading error message
- **Where:** `scripts/doppler-get.sh` — the `HOMELAB_USER` check prints "USER is not set".

### C3. Dead code
- `SERVICES_DIR` in `scripts/doppler-get.sh` is never used, and the directory doesn't exist.
- Unused imports in `api/server.py`, `api/routes/tasks.py` and `api/routes/otps.py` (`subprocess`, `json`, `asyncio`, `jsonschema`, `load_dotenv`, `request`, `Response`). `jsonschema` could then come out of `requirements.txt`.
- The routes are declared `async def` but do only blocking work; plain `def` is clearer under gevent.

### C4. README is missing the `/otps/get` route
- **Where:** `README.md` API table.
