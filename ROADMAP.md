# hermes-box — roadmap & status

The plan, in the repo so it survives independent of any session memory.
See `README.md` (usage) and `CLAUDE.md` (working conventions). To confirm live state
in a fresh session: `./scripts/test.sh`.

## Vision

A small Linux box on the Mac (Apple `container`), reachable only over the Tailscale
tailnet (SSH from anywhere, nothing on LAN/internet), with a host work folder mounted
as its home, fully reproducible from this repo, that eventually supports Hermes.

It is separate from the existing `hermes` container (`nousresearch/hermes-agent`,
run by `~/AiInfra/run-hermes.sh`, already under launchd).

## Done

- [x] Box on `container run` — real bidirectional `--volume` bind mounts
      (`container machine` can only mount the Mac home; rejected — see git `b76fdd5`).
- [x] Tailscale SSH via `--cap-add CAP_NET_ADMIN/CAP_NET_RAW`; `entrypoint.sh` starts
      tailscaled + creates the box user from env (no systemd).
- [x] Tailscale identity persisted in a named volume (`<name>-tsstate`) — survives
      recreate with no re-auth (bind mounts break tailscaled's state-store chmod).
- [x] Portable: all config via env with defaults from `id`/`$HOME`, overridable via
      gitignored `.env` (`.env.example` is the template). No hardcoded paths.
- [x] By-role layout: `image/`, `lib/`, `scripts/`.
- [x] Scripted, idempotent, documented; `scripts/test.sh` is the canonical check.
- [x] Tailnet name `hermes-box` reclaimed (`ssh nilushan@hermes-box`).
- [x] Auto-start at login via launchd (`scripts/autostart-install.sh`).

## Next decision (blocks Phase 2)

**What is hermes-box *for* relative to the `hermes` container?** Pick one:

1. **Hermes runtime** — fold Hermes into hermes-box (run gateway here, import
   `~/.hermes`, `--volume ~/.hermes:/opt/data`, `--publish 9119/8642`). Likely
   supersedes `run-hermes.sh`. One box: Tailscale access + Hermes + work folders.
2. **Hermes's sandboxed workspace** — keep the `hermes` container separate; hermes-box
   is the isolated env the agent SSHes into to run arbitrary commands (the original
   "runs arbitrary commands" intent).

## Remaining phases (after the decision)

- [ ] Phase 2 — Hermes per the decision above (data volume, import state, ports).
- [ ] Caddy / reverse proxy for any HTTP services.
- [ ] Backups — `restic` → Cloudflare R2 for `hermes-home` (+ key state); tested restore.

## How to resume in a new session

1. `cd ~/AiInfra/hermes-dev`
2. `./scripts/test.sh` — confirm the box is healthy.
3. Read this file + `CLAUDE.md`; make the role decision; build the next phase as
   scripts, then `./scripts/test.sh`, update docs, commit.
