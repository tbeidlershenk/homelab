# Dev VM: first bootstrap test (ROADMAP Phase 1b)

This doc has two audiences: **Part A** is for the owner, setting up the VM; **Part B** is the brief for a Claude Code session running *inside* the VM.

**Goal:** prove that `sudo ./bootstrap.sh` takes a fresh Ubuntu machine to a working homelab host. That means:
- the playbook runs without errors;
- a second run reports `changed=0`;
- the API answers;
- Dockhand is up.

This is the first real execution of the Ansible playbook from Phase 1. It has passed lint and syntax checks, but it has never run on a machine.

---

## Part A — Owner setup

### 1. Doppler `dev` config
Copy the `stage` config to a new `dev` config in the same project, then set or override:

| Variable | Value |
|---|---|
| `BASE_DIR` | `/home/ubuntu/homelab` |
| `DATA_DIR` | `/home/ubuntu/homelab/data` |
| `BACKUP_DIR` | `/home/ubuntu/homelab/backup` |
| `HOMELAB_USER` | `ubuntu` |
| `TAILSCALE_HOSTNAME` | `homelab-dev` |
| `TAILSCALE_AUTHKEY` | an **ephemeral** key tagged `tag:dev`, or any dummy if the first run skips Tailscale (see Part B) |
| `GITHUB_PAT`, `TAILSCALE_CI_AUTHKEY`, `SIYUAN_ACCESS_AUTH_CODE`, `REPO`, `EMAIL` | dummy values are fine. `doppler-get.sh` requires them to be set, but dev never uses them (`github_setup: false`) |
| `MACOS_HOSTNAME`, `MACOS_MAC_ADDRESS`, `MACOS_OTP_SERVER_PORT` | dummies are fine. The API needs them to start; `/otps/get` won't work in dev |

Never put prod credentials in `dev`. Then create a **service token scoped to the `dev` config only**.

### 2. Multipass and the VM
```bash
# Linux:  sudo snap install multipass
# macOS:  brew install --cask multipass   (or the installer from multipass.run)
multipass launch 24.04 --name homelab-dev --cpus 2 --memory 4G --disk 20G
multipass shell homelab-dev
```

### 3. Inside the VM
```bash
git clone -b phase1-ansible https://github.com/tbeidlershenk/homelab.git ~/homelab
cd ~/homelab
cat > .env <<'EOF'
DOPPLER_PROJECT=<project>
DOPPLER_CONFIG=dev
DOPPLER_TOKEN=<dev service token>
EOF
chmod 600 .env

# Claude Code (native installer), then log in on first launch
curl -fsSL https://claude.ai/install.sh | bash
exec $SHELL -l          # pick up PATH
claude                  # from ~/homelab; first message: "Read docs/DEV-VM.md Part B and start"
```

- **Clone inside the VM; don't use `multipass mount`.** It's closer to a real fresh machine, and the `base` role's `setfacl` probably won't work on a Multipass mount.
- **Starting over:** `multipass delete --purge homelab-dev`, then repeat step 2.

---

## Part B — Brief for the Claude session in the VM

**Read first:** `CLAUDE.md`, then `docs/ROADMAP.md` (decisions and status). For background, `docs/issues/architecture.md` explains the problems each phase fixes, and `docs/issues/tweaks.md` lists small fixes and their status.

### Context
- **You're on a disposable Multipass VM** (`ENVIRONMENT=dev`, user `ubuntu`, repo at `~/homelab` = `BASE_DIR`), not the prod server. The prod server is currently down, and nothing here touches it.
- **Branch `phase1-ansible`** holds the new playbook (`ansible/`) and is stacked on `phase0-security`. Neither is merged yet.
- **The owner's settled decisions** are in ROADMAP's "Decisions" section. Don't re-open them. In particular, Dockhand stays the place services are defined, and the playbook uses built-in modules only.
- **`vars/dev.yml`** turns off GitHub setup, CI secrets and cloudflared, and keeps `tailscale_up: true`.

### Steps
1. **Sanity checks**
   - `uname -m`: record the architecture. Prod is x86_64; arm64 here is OK but worth noting.
   - `lsb_release -ds` should show Ubuntu 24.04.
   - `.env` must exist with the three `DOPPLER_*` keys. Don't print its values.
2. **First run.** Ask the owner whether a real `tag:dev` Tailscale key is in Doppler.
   - If not, skip Tailscale for now using extra vars, which override `vars/dev.yml` with no code change:
     ```bash
     sudo ./bootstrap.sh -e tailscale_up=false 2>&1 | tee ~/first-run.log
     ```
   - Otherwise run plain `sudo ./bootstrap.sh 2>&1 | tee ~/first-run.log`.
3. **Second run, the idempotence check.** Same extra vars as step 2:
   ```bash
   sudo ./scripts/prepare.sh [-e tailscale_up=false] 2>&1 | tee ~/second-run.log
   ```
   The recap line for `homelab` must show `changed=0`. Any task that reports changed is a bug: fix the task's `changed_when` or its logic. CI enforces the same check.
4. **Verify the host**
   - `curl -s localhost:5001/` returns `{"status": "ok"}`.
   - `systemctl is-active api tailscaled docker` all report active. cloudflared should be absent or inactive in dev.
   - `stat -c '%a' /etc/homelab/.env` is `600`.
   - `sudo docker ps` shows `dockhand`, and `curl -sI localhost:4000` answers.
   - `curl -sN localhost:5001/tasks/run/does-not-exist` returns 404, and `curl -sN 'localhost:5001/tasks/run/..%2Fx'` returns 404. These are the Phase 0 checks.
   - `ls /etc/apt/sources.list.d/` contains deb822 `.sources` files for docker and tailscale, and Doppler's list.
5. **Restart-on-change** (the A1 fix). Append a comment to `api/server.py` and run `prepare.sh` again: exactly the API source-hash task and the `Restart api` handler should change. Revert the edit and run once more to return to `changed=0`.
6. **Optional, after a clean pass:** have the owner destroy and relaunch the VM and repeat steps 2–4, to prove the bootstrap from nothing is repeatable.

### When something fails
- Fix it in the repo on `phase1-ansible`: a new commit, with the attribution trailer from your instructions. Re-run, and keep each fix small and explained.
- Keep `ansible-lint -p site.yml roles` (run from `ansible/`) passing; CI enforces the production profile. On the VM: `sudo apt install -y pipx && pipx install ansible-lint`.
- Likely problem areas, given what was never executed:
  - the `deb822_repository` key downloads;
  - `ansible.builtin.pip` with `virtualenv_command`;
  - `dockhand`'s `changed_when` (it matches compose's stderr);
  - the `github` role (should be skipped in dev);
  - the `base` ACL task;
  - `callback_result_format` with Ubuntu's `ansible-core` 2.16.
- Pushing needs the owner's GitHub credentials. Commit locally and ask the owner to push, or ask before setting up `gh auth`. **Don't** use the prod `GITHUB_PAT`.

### Don't
- Merge anything to `main`, or ask to. There's a merge freeze until this test passes; the owner merges.
- Touch prod, its Doppler `prod` config, or GitHub repo secrets.
- Commit `.env`, logs, or anything under `data/` or `backup/`.
- Reorganize roles or start later phases. This session is about making Phase 1 run cleanly and repeatably.

### Report back (to the owner)
Report:
- architecture and OS;
- pass or fail for each of steps 2–5;
- every fix you committed, with a one-line reason each;
- anything you couldn't fix.

Then update `docs/ROADMAP.md`: tick "First real run" in the Phase 1 follow-ups, and note any new follow-ups. The next step after this is codifying the VM into `dev/cloud-init.yaml` and `dev/Makefile` (ROADMAP Phase 1b), but only once the owner asks for it.
