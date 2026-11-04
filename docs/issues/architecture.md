# Architecture

> Detailed problem analysis, the target architecture and research notes. **For phases and status, see [`docs/ROADMAP.md`](../ROADMAP.md).** Small fixes live in [tweaks.md](tweaks.md).

Structural problems that need a design decision, plus the agreed target architecture and migration roadmap. Small, single-PR fixes live in [tweaks.md](tweaks.md).

**Decisions so far**
- **Dockhand stays the source of truth for services.** You define and toggle compose stacks in its UI, and that workflow doesn't change. The goal is to *protect* those definitions, not move them into this repo.
- **The host layer moves to Ansible.** The one-command bootstrap from a fresh machine stays (`bootstrap.sh` → `ansible-playbook`).

---

## How it works today

```
GitHub push → Actions joins tailnet → GET homelab:5001/tasks/run_unattended/deploy
  → API (root, gunicorn) spawns deploy.sh → git stash --all / reset --hard → prepare.sh → restart.sh
       prepare.sh: Doppler → /etc/homelab/.env, setfacl -R $BASE_DIR, gh auth + ssh-key add,
                   push GH secrets (prod), copy units/wrappers, pip install, enable services
       restart.sh: compose up Dockhand, `docker restart` every running container
Services:  defined in the Dockhand UI (state in data/dockhand)
Schedules: Cronicle (outside repo) → api/scripts/run_task.py → /tasks/run/<script>
State:     data/, backup/, logs/ all live inside the git checkout
```

---

## Problems

### A1. Deploys don't restart the API
- **Where:** `scripts/deploy.sh` → `prepare.sh` / `restart.sh`
- **Problem:** `prepare.sh` runs `systemctl enable --now api`, which does nothing if the service is already running (the `restart` is commented out). `restart.sh` only restarts Docker containers. Merged API changes don't go live, and the CI health check still passes against the old process.
- **Complication:** The deploy runs *as a child of the API* (`run_unattended` → `deploy.sh`). Restarting `api` from inside the deploy may kill the deploy, because systemd kills the unit's whole cgroup by default (`start_new_session` doesn't escape it).
- **Resolved by:** Phase 1 (an Ansible handler restarts the API only when its code, requirements or unit changed) and Phase 2 (the deploy runs from its own systemd timer, not as a child of the API).

### A2. Deploy health check can't tell whether the deploy happened
- **Where:** `.github/workflows/deploy.yml`
- **Problem:** CI fires `run_unattended/deploy`, sleeps 60s, and checks that `/` returns 200. That passes if the deploy failed, is still running, or never started, because the old API keeps answering. The trigger `curl` doesn't use `-f`, so even a failed trigger isn't caught.
- **Resolved by:** Phase 2. The applied git SHA is written to disk and reported by the API, so you can see what's live; CI no longer deploys at all.

### A3. Remote code execution as root is the control-plane design
- **Where:** `config/api.service` (`User=root`), `api/routes/tasks.py`, `config/wrappers/api_start.sh` (`--bind 0.0.0.0:5001`)
- **Problem:** The API runs as root and runs any script on request, with no auth (see S1, S2). Anyone who compromises the API, or any device on the LAN or tailnet, owns the box.
- **Resolved by:** Phase 3 (non-root, bound to the tailnet, token auth, allowlist) plus Tailscale ACLs in Phase 8.

### A4. Code and live state share a directory
- **Where:** `scripts/deploy.sh`, `scripts/prepare.sh`, the `.gitignore` layout
- **Problems:**
  - `data/` (live Docker volumes), `backup/` and `logs/` live inside the git checkout.
  - `git stash --all` on every deploy adds a stash that's never dropped. With `--all` it also stashes *ignored* files, which here may include `.env`, `api/venv`, `logs/` and possibly `data/` / `backup/`. That could be slow, and it removes files that running services depend on until `prepare.sh` recreates them. *Checked 2026-11-04:* `git stash list` is empty, so stashes aren't piling up today (likely there were no local changes at past deploys). The `--all` risk still applies to any deploy that runs while there are untracked or ignored changes.
  - `prepare.sh` runs `setfacl -R` (and `-Rd`) over all of `$BASE_DIR` on every deploy. That recursively rewrites ACLs on live container volumes. It's slow as data grows, and it can change permissions that containers such as databases depend on.
  - The Claude Code deny rules for `data/**` and `backup/**` exist to work around this same layout.
- **Resolved by:**
  - Phase 0/1: state moves to `/srv/homelab/{data,backups,logs}`, declared in the Ansible `base` role. `DATA_DIR` / `BACKUP_DIR` are updated in Doppler.
  - Phase 2: the stash disappears entirely. `reset --hard` leaves ignored files alone anyway, and `ansible-pull` manages its own checkout.

### A5. Backups are local-only, unversioned and fragile
- **Where:** `scripts/backup.sh`
- **Problems:**
  - `backup/` is on the same disk, inside the same directory as `data/`, so a disk failure or a bad `git`/`rm` loses both.
  - The Filen CLI is installed but unused.
  - `rsync -av` without `--delete` keeps deleted files forever. With no snapshots, it keeps only the latest copy of changed files, so corruption gets backed up over the good copy.
  - Containers stay stopped if rsync fails, because `set -e` exits before the restart step.
  - There is no restore test, and no notification on failure.
  - The schedule lives in Cronicle, outside the repo.
- **Resolved by:** Phase 5.

### A6. CI tests the wrong thing
- **Where:** `.github/workflows/deploy.yml` (`test` job)
- **Problem:** It runs `install.sh`, `prepare.sh` and `backup.sh` with the `stage` config, which skips Tailscale, GitHub SSH and cloudflared. It never checks that the API starts or answers. There's no shellcheck or Python lint, so bugs like B1/B2 reach prod.
- **Resolved by:** Phase 2 (CI runs `ansible-lint`, `shellcheck`, a Python syntax/lint check, and `ansible-playbook --check`). Optionally, Phase 9 adds a periodic bootstrap in a VM.

### A7. Dockhand is a single point of failure for service definitions
- **Where:** `dockhand/compose.yml`, `data/dockhand`
- **Context:** Keeping services in Dockhand is a deliberate choice. Git history shows stacks moving out of the repo (filebrowser, siyuan, hotround) through Dockge → Portainer → Dockhand.
- **Problems:**
  - A fresh bootstrap produces a box with no services. Recovery depends entirely on `data/dockhand` surviving, and today that's only backed up to the same disk.
  - Stack edits have no history: you can't diff changes or roll back a compose file that broke a service.
  - `fnsys/dockhand:latest`, and likely `:latest` tags inside stacks, mean the blanket `docker restart` / `compose up` in `restart.sh` can pull a breaking version.
  - Dockhand runs as root with the Docker socket mounted, published on all interfaces (`4000:3000`). That makes it root-equivalent and reachable from the LAN.
- **Resolved by:**
  - Phase 1: pin the Dockhand image and bind the port to the tailnet.
  - Phase 5: `data/dockhand` becomes tier 1 in offsite backups.
  - Phase 6: a nightly read-only export of stacks to git. *To verify:* how Dockhand stores stacks on disk.
  - Phase 8: Renovate on the exported stacks.

### A8. Secrets are well-sourced but poorly scoped
- **Where:** `scripts/doppler-get.sh`, `scripts/doppler-save.sh`, `scripts/prepare.sh`, `config/wrappers/*`
- **Problems:**
  - Every Doppler secret lands in one `/etc/homelab/.env` that every unit sources (api, tailscaled, cloudflared). There's no least privilege, and the file is probably 0644 (S3).
  - Every script `eval`s the downloaded secrets (S6).
  - `prepare.sh` uploads the server's root SSH private key to GitHub Actions secrets, but the workflow never uses it (S7).
  - The PAT ends up in `~/.gitconfig` (S4). `gh ssh-key add` runs on every deploy.
  - Bootstrapping depends on a hand-placed repo `.env` holding a Doppler token that can read every secret in the config.
- **Resolved by:**
  - Phase 0: S3, S4, S6 and S7.
  - Phase 1: the `secrets` role renders one 0600 env file per service, containing only the variables that service uses.
  - Consider using a read-only Doppler service token scoped to the single config.

### A9. Provisioning is imperative, with no drift detection
- **Where:** `scripts/install.sh`, `scripts/prepare.sh`
- **Problems:**
  - `install.sh` runs `apt upgrade -y` and `curl | sh` for five vendors on every run (S5). Two runs a week apart produce different hosts.
  - Idempotence is hand-rolled with `if` guards.
  - Nothing reports when the box diverges from the repo.
  - dev/stage/prod differences are scattered `if [ $ENVIRONMENT == ... ]` branches.
- **Resolved by:** Phase 1 (Ansible roles, per-environment `group_vars`) and Phase 4 (a nightly `--check --diff` drift report).

### A10. Schedules live outside the repo
- **Where:** Cronicle (referenced in `api/scripts/run_task.py`); `scripts/hotround_scrape.sh`
- **Problems:**
  - The backup and hotround schedules are invisible to git.
  - `hotround_scrape.sh` clones a repo and `pip install`s onto the host at run time. That's unpinned, mutates the host, and runs as root via the API.
- **Resolved by:** Phase 4.

### A11. No observability or alerting
- **Where:** `config/prometheus.config.yml` (nothing references it)
- **Problem:** Deploy, backup and scrape failures are silent: they go to `logs/` and the journal, and nobody is notified. There are no uptime checks for public services and no disk-usage alerts, which is especially risky while `backup/` shares the disk.
- **Resolved by:** Phase 4 (`OnFailure` notifications) and Phase 7.

### A12. Edge and network config isn't code
- **Where:**
  - Cloudflare tunnel ingress lives in `data/cloudflared/config.yml` (gitignored).
  - Tailscale ACLs and tags live in the admin console.
  - Cloudflare DNS is presumably edited by hand.
- **Problem:** Exposing a service, or changing who can reach `:5001` / `:4000`, is unreviewed and not reproducible.
- **Resolved by:** Phase 8.

### A13. Unpinned versions and no update automation
- **Where:** `install.sh` installers, the cloudflared `latest` `.deb`, `dockhand:latest`, the `actions/checkout@v3` workflow actions
- **Problem:** Updates happen either by accident (`latest`) or never (the pinned Python deps). Nothing proposes updates for review.
- **Resolved by:** Phase 1 (pin versions in Ansible vars) and Phase 8 (Renovate + `unattended-upgrades`).

---

## Target architecture

```
repo (this one)
  bootstrap.sh                   fresh machine: install ansible → run site.yml
  ansible/
    site.yml, inventory.yml
    group_vars/{prod,stage,dev}.yml   per-environment settings (replaces if-branches)
    roles/
      base/         packages, users, /srv/homelab layout, firewall
      docker/       Docker apt repo, pinned
      tailscale/    install + `up` when not logged in
      cloudflared/  pinned; ingress rendered from vars (prod)
      secrets/      Doppler → per-service env files, 0600
      api/          venv, unit, handler restarts only on change
      dockhand/     pinned image, tailnet-bound port
      timers/       deploy (ansible-pull), backup, hotround, drift check, stack export
      backups/      restic/Backrest config, hooks, retention
      monitoring/   node-exporter, Prometheus, Gatus/Uptime Kuma, ntfy alerts
  .github/workflows/   lint + `ansible-playbook --check` on PRs (no deploy step)
  renovate.json
private repo           nightly read-only export of Dockhand stacks

/srv/homelab/{data,backups,logs}   state, outside the checkout
Dockhand                           live service definitions (unchanged workflow)
Doppler                            secrets
restic repo (local + offsite)      data, including data/dockhand
```

**End state:**
- A fresh machine needs one command plus a restore.
- Merging to `main` is the deploy, pulled by the box itself; nothing reaches *into* the box.
- Restarts happen only when something changed.
- Failures notify you.

---

## Migration roadmap

The phases, their status and next steps live in **[`docs/ROADMAP.md`](../ROADMAP.md)**, the single source of truth. The "Resolved by: Phase N" notes above use the same numbering. The dev environment is ROADMAP Phase 1b (after the Ansible migration).

---

## Research: what other homelabs do

| Pattern | Examples | Fit |
|---|---|---|
| Ansible for host config + Compose for apps | Common on single-box labs, often with a container UI kept for viewing | **Chosen** for the host layer |
| Pull-based GitOps for Compose stacks | doco-cd, Komodo, docker-git-deploy (systemd timer + `compose up --wait` + rollback) | Not adopted for services (Dockhand stays); the pull model is reused for the host via `ansible-pull` |
| NixOS flake + deploy-rs / Colmena | Many public homelab flakes; deploy-rs rolls back automatically | Most declarative, but a full rewrite and an OS change |
| k3s + Flux / ArgoCD | khuedoan/homelab and similar | Overkill for one box |
| restic / Backrest / borgmatic with hooks, retention, offsite, `check`, restore drills | Standard in homelab write-ups | **Chosen** (Phase 5) |
| Renovate for pinned versions | Ubiquitous in GitOps labs | **Chosen** (Phase 8) |
| Edge as code (Tailscale ACL GitOps, tunnel ingress in git, OpenTofu DNS) | Common in IaC-heavy labs | **Chosen** (Phase 8) |
| Gatus / Uptime Kuma + Prometheus + ntfy | Standard | **Chosen** (Phase 7) |

Sources:
- [docker-git-deploy](https://github.com/armstrys/docker-git-deploy)
- [khuedoan/homelab](https://github.com/khuedoan/homelab)
- [doco-cd discussion](https://piefed.nullspace.lol/post/40110)
- [doco-cd review](https://cloudzy.com/blog/doco-cd-review/)
- [Komodo / doco-cd thread](https://lemmy.klein.ruhr/post/167003/722274)
- [Portainer → Ansible thread](https://reddit.sentinel-team.org/posts/1tx96iw/snapshots/2026-06-05T10%3A50%3A26.816143Z)
- [NixOS deployment tools](https://discourse.nixos.org/t/deployment-tools-evaluating-nixops-deploy-rs-and-vanilla-nix-rebuild/36388)
- [Colmena docs](https://colmena.cli.rs/unstable/print.html)
- [NixOS as a server](https://wiki.nixos.org/wiki/NixOS_as_a_server)
- [Restic/Backrest guide](https://gitea.kelinreij.duckdns.org/kelin/EZ-Homelab/src/tag/v0.1.0/docs/Restic-BackRest-Backup-Guide.md)
- [Backup strategy](https://gitea.kelinreij.duckdns.org/kelin/EZ-Homelab/src/commit/ef55974b505a40b094015b117a0fa2949c1fa34f/wiki/Backup-Strategy.md)
