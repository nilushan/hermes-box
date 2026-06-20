# hermes-box — roadmap & status

The plan, in the repo so it survives independent of any session memory.
See `README.md` (usage) and `CLAUDE.md` (working conventions). To confirm live state
in a fresh session: `./scripts/test.sh`.

## Vision

A single box on the Mac (Apple `container`) that **is the Hermes runtime** — runs the
Hermes gateway *and* Tailscale, reachable only over the tailnet (SSH from anywhere,
nothing on LAN/internet), with data + work folders bind-mounted from a consolidated
backup-friendly root, fully reproducible from this repo. Supersedes the old standalone
`hermes` container / `run-hermes.sh`.

## Done

- [x] Box on `container run` — real bidirectional `--volume` bind mounts.
- [x] **Box is the Hermes runtime**: image `FROM nousresearch/hermes-agent` + Tailscale
      added as an s6-overlay service; one container runs gateway + dashboard + tailscaled.
- [x] Tailscale via `--cap-add CAP_NET_ADMIN/CAP_NET_RAW`; identity in a named volume
      (`<name>-tsstate`) — recreate with no re-auth.
- [x] **Consolidated data root** `~/AiInfra/hermes-box-data/` (`.hermes/` + `hermes-home/`),
      migrated off `~/.hermes` and `~/AiInfra/hermes-home` (`scripts/migrate-data.sh`).
- [x] **Backup/restore** of the data root (`scripts/backup.sh` / `restore.sh`, lean tar).
- [x] Old standalone `hermes` retired: container removed, `com.ownstack.hermes` launchd
      agent disabled (`.plist.disabled`), Pi-era tailscale leftovers in `.hermes` removed.
- [x] Portable (env + `.env`), by-role layout, scripted/tested, name `hermes-box`,
      launchd auto-start at login.

## Remaining phases

- [ ] **Backups offsite** — `restic` → Cloudflare R2 (versioned, offsite). Local tar
      snapshots exist but the Mac disk is tight; this is the real backup. Needs R2 creds.
- [ ] **Free Mac disk space** — the volume runs ~90–96% full; the fat Hermes image needs
      headroom to rebuild. Operational, but it blocks `01-build.sh` when too full.
- [ ] Caddy / reverse proxy if services need TLS / clean hostnames.

## How to resume in a new session

1. `cd ~/AiInfra/hermes-dev`
2. `./scripts/test.sh` — confirm the box is healthy.
3. Read this file + `CLAUDE.md`; make the role decision; build the next phase as
   scripts, then `./scripts/test.sh`, update docs, commit.
