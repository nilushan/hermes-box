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
- [x] **Backup/restore** of the data root (`scripts/backup/backup.sh` / `restore.sh`, lean tar).
- [x] Old standalone `hermes` retired: container removed, `com.ownstack.hermes` launchd
      agent disabled (`.plist.disabled`), Pi-era tailscale leftovers in `.hermes` removed.
- [x] Portable (env + `.env`), by-role layout, scripted/tested, name `hermes-box`,
      launchd auto-start at login.
- [x] **Caddy over the tailnet** (s6 service, Tailscale TLS cert, bound to tailnet IP):
      serves the **wiki** (`https://<fqdn>/`) and the **Hermes dashboard**
      (`https://<fqdn>:8443/`, Host/Origin rewrite). Replicates the Pi setup.

- [x] **Offsite backups — restic → Cloudflare R2** (encrypted, versioned). CF infra
      scripted (`cf-r2-setup.sh`: bucket + S3 creds from a CF API token). `restic-backup.sh`
      (init+backup+prune 7d/4w/6m), `restic-restore.sh`, `restic-snapshots.sh`. Daily
      launchd timer (`restic-schedule-install.sh`, 03:00). Backup + restore verified.

## Remaining phases

- [ ] **Free Mac disk space** — the volume runs ~90% full; the fat Hermes image needs
      headroom to rebuild. `scripts/builder/reset.sh` reclaims the BuildKit cache before
      a build, but the Mac is genuinely tight.
- [ ] (Deferred, not wanted now) host the `sites/` (ownstack, tanglinlaw) — Astro builds.
- [ ] Bake `mkdocs` into the image so the wiki can rebuild in-box (currently host-built).

## How to resume in a new session

1. `cd ~/AiInfra/hermes-dev`
2. `./scripts/test.sh` — confirm the box is healthy.
3. Read this file + `CLAUDE.md`; make the role decision; build the next phase as
   scripts, then `./scripts/test.sh`, update docs, commit.
