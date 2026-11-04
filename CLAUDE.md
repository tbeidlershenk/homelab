# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Start here

- **`docs/ROADMAP.md`** is the migration plan: settled decisions, phase status, and what's next. Read it before proposing architectural changes, and update its status table when a phase moves.
- **Settled decisions** (details in the roadmap): Dockhand stays the source of truth for services; the host is managed by Ansible; Doppler holds secrets; the dev VM comes after the Ansible migration.
- `docs/issues/` (gitignored, may be absent on a new machine) holds detailed security notes. Don't commit it.

## What this repo is

Infrastructure-as-code for a single self-hosted Linux server: an Ansible playbook for the host, systemd units, and a small Flask "control-plane" API. **The server's checkout of this repo is the live deployment.** `BASE_DIR` points at it, and `data/` (live Docker volumes), `backup/` and `logs/` sit inside it, gitignored. On the server, do all work on a branch in a separate worktree (`git worktree add ../homelab-<topic> -b <topic>`), never in the live checkout: services run from it, and `deploy.sh` hard-resets it. Containers are managed in Dockhand, not by compose files here; only `dockhand/compose.yml` itself is tracked.

## Commands

```bash
sudo ./bootstrap.sh                          # fresh machine: install.sh then prepare.sh
sudo ./scripts/install.sh                    # prerequisites only: ansible-core, python3-debian, Doppler
sudo ./scripts/prepare.sh                    # apply ansible/site.yml (idempotent); args pass through:
sudo ./scripts/prepare.sh --check --diff     #   dry run: show what would change
sudo ./scripts/backup.sh                     # rsync $DATA_DIR -> $BACKUP_DIR
./scripts/deploy.sh                          # CI-triggered: detach, reset to origin/main, prepare, restart

cd ansible && ansible-lint -p site.yml roles # lint (CI enforces the production profile)
ansible-playbook --syntax-check site.yml     # from ansible/, with ANSIBLE_CONFIG=ansible.cfg

sudo systemctl restart api && journalctl -u api -f
journalctl -u 'homelab-deploy-*'             # logs from detached deploys
curl -N http://localhost:5001/tasks/run/<name>   # run scripts/<name>.sh, stream output as SSE
```

To run the API in the foreground for development: `cd api && venv/bin/python server.py` (Flask debug server on port **5000**; production gunicorn uses **5001**). Load the environment first: `set -a; source /etc/homelab/.env; set +a`.

## Architecture

**Settings and secrets flow (Doppler → environment → Ansible).**
- The repo-root `.env` holds only `DOPPLER_PROJECT` / `DOPPLER_CONFIG` / `DOPPLER_TOKEN`.
- `scripts/doppler-get.sh` is *sourced* by every script. It downloads secrets as JSON and exports them with `shlex.quote`, so values are never executed. It then checks the required variables and derives `ENVIRONMENT` (= the Doppler config name), `LOGS_DIR` and similar. `DATA_DIR` and `BACKUP_DIR` come from Doppler itself.
- `ansible/group_vars/all.yml` reads those variables with `lookup('env', ...)`. A new setting is added in Doppler, then mapped there; if it's required, also add a check in `doppler-get.sh`.
- `scripts/doppler-save.sh` writes `/etc/homelab/.env` (mode 0600) for the systemd wrappers. The `secrets` role runs it and sets `secrets_changed`, which triggers service restarts.

**Ansible layout.**
- `ansible/site.yml` applies roles in this order: `base` → `docker` → `github` → `secrets` → `tailscale` → `cloudflared` → `api` → `dockhand`.
- Per-environment toggles live in `ansible/vars/{prod,stage,dev}.yml`, loaded by `include_vars`: `github_setup`, `github_ci_secrets`, `tailscale_up`, `cloudflared_enabled`, `filen_enabled`. `stage` is the GitHub Actions runner; `dev` is the future Multipass VM.
- Conventions:
  - built-in modules only (no Galaxy collections);
  - registered variables are prefixed with the role name;
  - command and shell tasks always declare `changed_when`;
  - services restart only via handlers, when something they depend on changed.
- The `api` role detects code changes with a source hash, stored in `/etc/homelab/api.source.sha256`.
- `repo_root` is the checkout the playbook runs from (`playbook_dir/..`); `base_dir` is the live checkout. They are the same in prod.

**systemd services.**
- `config/*.service` call wrappers in `config/wrappers/`. The roles copy the units to `/etc/systemd/system/` and the wrappers to `/etc/homelab/`, which is what systemd actually runs.
- The wrappers source `/etc/homelab/.env` and `exec` the real process.
- Tailscale state lives in `data/tailscale`, and the cloudflared config in `data/cloudflared/config.yml`.

**API (`api/`).**
- `server.py` registers two blueprints. `wsgi.py` is the gunicorn entrypoint (gevent workers, `--timeout 0` so long SSE streams aren't killed).
- `routes/tasks.py` serves `/tasks/run/<name>` (streams `pid` / `stdout` / `stderr` / `done` SSE events, and SIGINTs the process group if the client disconnects) and `/tasks/run_unattended/<name>` (detached). Names must match `[A-Za-z0-9_-]+` and resolve to a file directly in `scripts/`; scripts run as `bash <path>` with no shell. Any `.sh` added to `scripts/` can be called remotely.
- `routes/otps.py` (`/otps/get`): Wake-on-LAN to a Mac, then calls its `/caffeinate` and `/otps` endpoints.
- Callers today: CI (over Tailscale), Cronicle (a container, using `api/scripts/run_task.py`), devices on the tailnet, and a LAN device. Binding the API only to the tailnet would break the LAN device.
- Missing env vars make modules `sys.exit(1)` at import time. `from logger import logger` is the PyPI `logger` package, not a local module.

**CI/CD (`.github/workflows/deploy.yml`).**
- **PRs:** `ansible-lint`, then on a fresh Ubuntu runner (Doppler `stage`): install → prepare → **prepare again, which must report `changed=0`** → backup. Keep every task idempotent.
- **Push to `main`:** the runner joins Tailscale, calls `/tasks/run_unattended/deploy`, waits 60s, then health-checks `/`. Merging to `main` deploys to the live box.
- `deploy.sh` re-launches itself via `systemd-run`, so it survives an API restart. It then runs `git stash` (tracked files only), `reset --hard origin/main`, `prepare.sh` and `restart.sh` (which restarts every running container).
- Phase 2 replaces this push flow with `ansible-pull`.

**Backups.** `backup.sh` stops containers labeled `pause_for_backup=true`, rsyncs `$DATA_DIR/` to `$BACKUP_DIR`, then starts them again.

## Working in this repo

- **Claude Code deny rules** in `.claude/settings.json` block reading `.env*`, `data/**` and `backup/**`. Don't work around them; they hold secrets and live volumes.
- **Validation without root:** `ansible-core` and `ansible-lint` can be pip-installed into a scratch directory for `--syntax-check` and lint. Real runs happen in CI (stage) or on the dev VM.
- **Git identity on the server:** the `HOMELAB_USER` account may have no git identity (the playbook sets one for root). Pass `-c user.name=... -c user.email=...` when committing.
