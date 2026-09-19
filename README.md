# Homelab

Infrastructure-as-scripts for a single self-hosted server: provisioning, secrets, a small control-plane API, container orchestration, and a self-triggered CI/CD deploy — all driven from this repo.

## Architecture at a glance

- **Host**: one Linux box running Docker + a handful of systemd services.
- **Secrets**: stored in [Doppler](https://www.doppler.com/), pulled down by scripts at run time and written to `/etc/homelab/.env` for services to source.
- **Networking**: [Tailscale](https://tailscale.com/) gives the box (and GitHub Actions runners) a private address; [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) exposes selected services publicly.
- **Containers**: managed with [Dockhand](https://github.com/fnsys/dockhand) (a Portainer replacement) rather than compose files checked into this repo.
- **Control plane**: a small Flask API (`api/`) running as a systemd service, used to trigger scripts (including deploys) remotely over Tailscale.
- **CI/CD**: a GitHub Actions workflow tests PRs against a fresh VM-equivalent setup, and on merge to `main` tells the server (via the API) to pull and redeploy itself.

## Repository layout

```
api/            Flask control-plane API (systemd service, port 5001)
config/         systemd unit files + their startup wrapper scripts
dockhand/       compose file for the Dockhand container-management UI
scripts/        provisioning, secrets, backup, and deploy scripts
data/           live Docker volumes for each service (gitignored)
backup/         rsync target for backups, mirrors data/ layout (gitignored)
logs/           script logs, e.g. backup.log (gitignored)
.github/        CI/CD workflow
```

## Bootstrapping a host

```bash
git clone https://github.com/tbeidlershenk/homelab.git && cd homelab
sudo ./scripts/install.sh   # apt packages, Docker, Tailscale, Cloudflared, Filen CLI
sudo ./scripts/prepare.sh   # directories, ACLs, systemd units, venv, bring services up
```

`prepare.sh` is idempotent and is also what `deploy.sh` re-runs on every deploy. It:

- Creates `logs/`, `backup/`, `data/`, `/etc/homelab`.
- Grants the non-root `HOMELAB_USER` ACL access to the repo directory.
- Sets up GitHub SSH access and (in `prod`) pushes deploy secrets to the GitHub Actions secrets (`SSH_PRIVATE_KEY`, `SSH_HOST`, `TAILSCALE_CI_AUTHKEY`, ...) so Actions can reach the box.
- Installs the three systemd units from `config/` and their wrapper scripts from `config/wrappers/` into `/etc/homelab/`.
- Brings up Tailscale, the API's Python venv, and (in `prod`) Cloudflared.

## systemd services

| Unit                  | Wrapper script                         | Purpose                                                                       |
| --------------------- | -------------------------------------- | ----------------------------------------------------------------------------- |
| `api.service`         | `config/wrappers/api_start.sh`         | Runs the Flask control-plane API via `gunicorn` on port 5001                  |
| `tailscaled.service`  | `config/wrappers/tailscaled_start.sh`  | Tailscale daemon, state kept in `data/tailscale` (not the default `/var/lib`) |
| `cloudflared.service` | `config/wrappers/cloudflared_start.sh` | Runs the `tbeidlershenk.dev-tunnel` Cloudflare Tunnel (prod only)             |

Each wrapper just sources `/etc/homelab/.env` and execs the real process — keeping the systemd units themselves free of secrets.

## API

A minimal Flask app (`api/server.py`) whose only job is letting trusted callers (you, over Tailscale; GitHub Actions, over Tailscale) run scripts on the box remotely.

| Route                                | Description                                                                                 |
| ------------------------------------ | ------------------------------------------------------------------------------------------- |
| `GET /`                              | Health check — `{"status": "ok"}`                                                           |
| `GET /tasks/run/<script>`            | Runs `scripts/<script>.sh`, streaming stdout/stderr back as Server-Sent Events              |
| `GET /tasks/run_unattended/<script>` | Fire-and-forget: starts `scripts/<script>.sh` detached and returns immediately with its PID |
