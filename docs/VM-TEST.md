# VM bootstrap test (`dev/vm-test.sh`)

An unattended, end-to-end test of the Ansible bootstrap on a throwaway Multipass VM. Run it on any machine with Multipass: a Linux box or a Mac, including Apple Silicon. It doesn't touch the prod server.

**What it proves:**
- `sudo ./bootstrap.sh` takes a fresh Ubuntu 24.04 VM to a working homelab host;
- a second run changes nothing;
- the host passes 12 checks;
- the API restarts only when its code changes.

When it finishes, the VM is gone and its Tailscale node is logged out.

This guide has two parts: **Part 1** is the owner's one-time laptop setup, and **Part 2** is the brief for the Claude Code session that runs the test.

---

## Part 1 — Owner: one-time setup on the laptop

1. **Install Multipass.**
   - macOS: `brew install --cask multipass` (or the installer from multipass.run)
   - Linux: `sudo snap install multipass`

   Check it with `multipass version`.
2. **Clone the repo** on the branch under test:
   ```bash
   git clone -b phase1-ansible https://github.com/tbeidlershenk/homelab.git ~/homelab
   ```
3. **Create the dev env file** outside the repo, at exactly this path (the committed `.claude/settings.json` denies Claude reading it):
   ```bash
   cat > ~/homelab-dev.env <<'EOF'
   DOPPLER_PROJECT=<project>
   DOPPLER_CONFIG=dev
   DOPPLER_TOKEN=<dev-scoped service token>
   EOF
   chmod 600 ~/homelab-dev.env
   ```
   The values the Doppler `dev` config needs are listed in `docs/DEV-VM.md` Part A, step 1.
4. **Tailscale:**
   - The Doppler `dev` key (`TAILSCALE_AUTHKEY`) must be **reusable and ephemeral**, tagged `tag:dev`. Each run joins the tailnet and leaves.
   - Remove any existing `homelab-dev` / `homelab-dev-N` nodes in the admin console, and stop any other dev VM that's logged in as `homelab-dev`. Otherwise the name check fails on a collision.
5. **Push access**, so the session can push fixes. Choose one:
   - `gh auth login`;
   - a fine-grained PAT limited to this repo (Contents: read/write) in a credential store file, with a deny rule for that file.

   Never use the prod PAT.
6. **Install Claude Code** (native installer, not a snap), then start it in the repo:
   ```bash
   curl -fsSL https://claude.ai/install.sh | bash
   cd ~/homelab && claude
   ```
   First message: **"Read docs/VM-TEST.md Part 2 and run the test."**

Resources: the VM takes 2 CPUs, 3 GB RAM and 15 GB disk while it runs. A full run takes about 10–15 minutes.

---

## Part 2 — Brief for the Claude session

**Read first:** `CLAUDE.md`, `docs/ROADMAP.md` (settled decisions and the **merge freeze**), then this section.

### Context
- **Branch:** `phase1-ansible` holds the Ansible host playbook (Phase 1). It has already passed a manual run on a dev VM. This test makes the from-scratch run repeatable and checks the fixes since then:
  - `flush_handlers` before `tailscale up`, so a fresh host logs in to `data/tailscale` and not the package's state dir;
  - `data/tailscale` mode `0700`.
- **The script clones from GitHub**, not from your working tree. **Any fix must be committed and pushed to `phase1-ansible` before re-running**, or the test runs the old code.

### Before running
1. Run `multipass version`. If it's missing, stop and ask the owner to install it.
2. Confirm `~/homelab-dev.env` exists: `test -r ~/homelab-dev.env && echo ok`. **Don't read, print or `cat` it**; it holds a Doppler token. The script itself checks that it says `DOPPLER_CONFIG=dev`.
3. Run `multipass list`. If a VM named `homelab-dev-test` exists from an earlier run, ask the owner before deleting it.
4. Run `git fetch && git status -sb` and confirm `phase1-ansible` is up to date with `origin`, with nothing unpushed.

### Run
```bash
cd ~/homelab
dev/vm-test.sh ~/homelab-dev.env phase1-ansible 2>&1 | tee /tmp/vm-test.out
```
It prints the commit under test, then each stage's Ansible recap and a `PASS`/`FAIL` line for every check. It ends with `ALL CHECKS PASSED`, or `N CHECK(S) FAILED` and a non-zero exit. Per-run logs land in `./vm-test-logs/` (gitignored):
- `first-run.log`: bootstrap
- `second-run.log`: idempotence
- `change-run.log`, `revert-run.log`, `settle-run.log`: restart-on-change

**Options:**
- `KEEP_VM=1`: leave the VM up afterwards, for debugging with `multipass shell homelab-dev-test`. You must clean up by hand afterwards (see below).
- `VM_NAME=...`: use a different VM name.
- `EXPECT_TS_NAME=...`: if Doppler `TAILSCALE_HOSTNAME` isn't `homelab-dev`.

### Reading failures

| Failure | Where to look | Usual cause |
|---|---|---|
| `bootstrap completes` | `first-run.log`, the first `fatal:` | a task broken on a fresh host: apt repo or key, a package, a missing variable from Doppler |
| `second run changed=0` | the script prints the changed tasks; or `grep -B1 '^changed:' vm-test-logs/second-run.log` | a task that isn't idempotent: a mode fighting an ACL or a daemon, a `command`/`shell` missing a correct `changed_when`, a handler ordering problem |
| `tailnet name has no -N suffix` | `tailscale status` in the VM (`KEEP_VM=1`) | a leftover node with the same name; or a double login (the `tailscale up` ordering) |
| `DNS works with Tailscale up` | `resolvectl status` in the VM | tailnet "Override DNS servers" pointing at the prod resolver while prod is down (ROADMAP Phase 1 follow-up) |
| `code change → source hash + API restart only` | `change-run.log` | the `api` role's fingerprint task or handler wiring |
| Script dies before the checks | `/tmp/vm-test.out` | Multipass launch/transfer problems, or no network in the VM |

### Fix loop
1. Fix in the repo on `phase1-ansible`. Keep each change small, with the reason in the commit message.
2. Run `cd ansible && ansible-lint -p site.yml roles`. It must pass at the production profile; CI enforces it. To install it: `pipx install ansible-lint`, or `pip install --user ansible-lint`.
3. Commit with the owner's identity, not your own:
   ```bash
   git -c user.name="Tobias Beidler-Shenk" -c user.email="tbeidlershenk@gmail.com" commit -m "..."
   ```
   End the message with the `Co-Authored-By` trailer your instructions give.
4. `git push origin phase1-ansible`, then re-run the whole test. It starts from nothing each time.

### Cleanup check (after every run)
- `multipass list` must not show `homelab-dev-test`. If it does, run `multipass delete --purge homelab-dev-test`.
- Ask the owner to confirm no `homelab-dev*` node lingers in the Tailscale admin console. Ephemeral nodes are removed on logout, and the script logs out first.
- If you ran with `KEEP_VM=1`: `multipass exec homelab-dev-test -- sudo tailscale logout`, then `multipass delete --purge homelab-dev-test`.

### Rules
- **Never merge to `main`, push to `main`, or open a PR targeting `main`.** The merge freeze holds until this test passes, and the owner merges. Push to `phase1-ansible` only.
- Don't read `~/homelab-dev.env`, `.env` or any credential file. Don't put secrets in commits or logs.
- Don't touch the prod server, Doppler `prod`, or the repo's GitHub secrets.
- Stay within Phase 1: fix what the test exposes, nothing else. Note anything bigger as a follow-up in `docs/ROADMAP.md`.

### Report back
When the test passes, or you're blocked, report:
- the commit tested, and the host OS and architecture (`uname -m`);
- `PASS`/`FAIL` for each check, from the final run;
- each fix you pushed, with a one-line reason;
- the result of the cleanup check;
- anything you couldn't fix.

Then update `docs/ROADMAP.md`. On a full pass, tick "Destroy/relaunch the dev VM and repeat from nothing" with the date and commit. Add any new follow-ups.
