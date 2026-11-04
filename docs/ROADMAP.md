# Homelab roadmap

The architecture migration plan and its status. **Update the status table whenever a phase moves.** A new session should be able to resume from this file plus `CLAUDE.md` alone.

## Decisions (settled — don't re-litigate without the owner)

1. **Dockhand stays the source of truth for services.** Compose stacks are created and toggled in the Dockhand UI, and they don't move into this repo. Protect them instead: backups, plus a read-only export to git (Phase 6).
2. **The host layer is Ansible** (`ansible/`). The one-command bootstrap from a fresh machine must keep working: `sudo ./bootstrap.sh`.
3. **Doppler stays the secrets and settings store.** The playbook reads everything from the environment that `scripts/doppler-get.sh` loads.
4. **Dev environment comes after the Ansible migration** (Phase 1b). It runs as a Multipass VM, built by the same playbook with `env=dev`.
5. **Detailed security findings stay out of git.** They're tracked locally in `docs/issues/` (gitignored). This file holds only phases, decisions and status.
6. **Use built-in Ansible modules only** (`ansible.builtin.*`), so the host needs nothing beyond `ansible-core` from apt. CI enforces `ansible-lint` (production profile) and a second, no-change run (idempotence).

## Status

| Phase | What | Status |
|---|---|---|
| 0 | Security quick fixes (task-name validation, secrets loading/permissions, PAT, CI secrets) | ✅ PR `phase0-security` |
| 1 | Ansible for the host | 🟡 core done on `phase1-ansible` (stacked on Phase 0); follow-ups below |
| 1b | Dev environment (Multipass VM) | ⏳ next, after Phase 1 merges |
| 2 | Pull-based deploys (`ansible-pull` timer), retire the CI → API deploy | ⏳ |
| 3 | API: non-root, tailnet/LAN firewall, token auth, task allowlist | ⏳ |
| 4 | Schedules as code: systemd timers replace Cronicle, `OnFailure` → ntfy | ⏳ |
| 5 | Backups v2: restic/Backrest, offsite, retention, restore drill | ⏳ |
| 6 | Read-only nightly export of Dockhand stacks to a private repo | ⏳ |
| 7 | Monitoring: node-exporter, Prometheus, Gatus/Uptime Kuma, alerts | ⏳ |
| 8 | Renovate, unattended-upgrades, tunnel ingress from vars, Tailscale ACL GitOps | ⏳ |
| 9 | Disaster-recovery drill: fresh VM → bootstrap → restore, plus a runbook | ⏳ |

## Phase 1 — Ansible for the host

**Done (branch `phase1-ansible`):**
- `ansible/` holds `site.yml`, a local inventory, `group_vars/all.yml` (env lookups) and `vars/{prod,stage,dev}.yml` toggles.
- Roles: `base`, `docker`, `github`, `secrets`, `tailscale`, `cloudflared`, `api`, `dockhand`.
- `scripts/install.sh` now installs only `ansible-core`, `python3-debian` and Doppler (from its apt repo). `scripts/prepare.sh` runs the playbook, and extra args pass through, e.g. `--check --diff`. `bootstrap.sh` runs both.
- **Restart-on-change** (fixes "deploys don't restart the API"): handlers restart services when their unit, wrapper, venv, source hash or secrets changed, and only then.
- **`deploy.sh` detaches** into a transient systemd unit (`homelab-deploy-*`). Restarting the API during a deploy no longer kills the deploy.
- `setfacl -R` no longer recurses into `data/` and `backup/` on every run.
- Vendor apt repos (deb822) replace `curl | sh` for Docker (only if absent), Tailscale and cloudflared. Filen keeps its installer, but it runs once.
- CI: `ansible-lint`, then install → prepare → **prepare again (it must report `changed=0`)** → backup.

**Phase 1 follow-ups (not yet done):**
- [ ] First real run: watch the PR's CI job, then the first prod run after merge (see "Rollout" below).
- [ ] Move state to `/srv/homelab/{data,backups,logs}`. Needs a one-time data move with services stopped, plus a Doppler `DATA_DIR`/`BACKUP_DIR` update. Owner-driven.
- [ ] Per-service env files (0600) with only each service's variables, replacing the single `/etc/homelab/.env`.
- [ ] Pin package versions in vars (pairs with Renovate in Phase 8).
- [ ] Host firewall in `base` (ufw/nftables): allow API `:5001` and Dockhand `:4000` only from the tailnet and specific LAN sources.
- [ ] Tag roles (`--tags api` etc.) for faster targeted runs.

**Rollout notes:**
- The server checkout *is* the live deployment (`BASE_DIR`), so do work on a branch in a separate worktree (e.g. `git worktree add ../homelab-<topic> -b <topic>`), never in the live checkout.
- The first prod run, after merge: `cd $BASE_DIR && git pull && sudo ./scripts/prepare.sh --check --diff` to review, then `sudo ./scripts/prepare.sh`. Expect changes to repo files (Tailscale/cloudflared move to deb822) and an API restart.

## Phase 1b — Dev environment (after Phase 1 merges)
- **Where:** a Multipass VM (`homelab-dev`, Ubuntu LTS), defined in `dev/cloud-init.yaml` and driven by `dev/Makefile`: `dev-up`, `dev-apply`, `dev-check`, `dev-destroy`.
- **How:** mount the repo into the VM and run the same playbook with `ENVIRONMENT=dev`. `vars/dev.yml` already disables GitHub setup and cloudflared.
- **Secrets:** a separate Doppler `dev` config with its own ephemeral Tailscale key (`tag:dev`) and no prod credentials.
- **Loop:** edit → `make dev-apply` → apply again (must be `changed=0`) → PR → merge. Rebuilding the VM regularly doubles as the bootstrap/DR drill.
- **Check first:** the host CPU architecture. On an Apple Silicon Mac the VM is arm64 while prod is amd64, so keep roles architecture-agnostic (the deb822 repos already are).

## Phase 2 onward
Short scope per phase. Expand each into a plan when it starts.
- **2:** `homelab-deploy.timer` → `ansible-pull --only-if-changed`; expose the deployed SHA; remove `/tasks/run_unattended/deploy`, `deploy.sh`, `restart.sh` (which restarts every container) and the CI tailnet join; CI = lint + `--check`.
- **3:** API runs as `HOMELAB_USER`, behind the firewall, with token auth and an explicit task allowlist; `sudoers` only where root is needed.
- **4:** timers for backup, hotround (as a pinned container) and a nightly `--check --diff` drift report; failures notify.
- **5:** restic/Backrest role with `pause_for_backup` hooks plus a `trap`; offsite storage (check Filen via rclone, else B2/S3); retention and `restic check`; Dockhand data is tier 1; periodic restore test.
- **6:** confirm how Dockhand stores stacks on disk, then add a nightly commit-on-change export.
- **7:** monitoring deployed by Ansible (so it survives Dockhand being down); disk, uptime, certificate and backup alerts.
- **8:** Renovate (vars, requirements, Actions, the exported stacks); cloudflared ingress rendered from vars; Tailscale ACL file in git; optionally OpenTofu for DNS.
- **9:** a rebuild drill and a written runbook.
