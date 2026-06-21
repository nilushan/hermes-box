# Hermes box

**The box IS the Hermes runtime.** A single `container run` container on macOS that
runs the Hermes gateway *and* Tailscale, reachable over the tailnet via Tailscale SSH,
with the work folder and Hermes data bind-mounted from a consolidated, backup-friendly
data root. Supersedes the old standalone `hermes` container / `run-hermes.sh`.

- **Image** (`image/Dockerfile`): `FROM nousresearch/hermes-agent` + Tailscale added as
  an **s6-supervised** service (the Hermes image uses s6-overlay). No rebuild of Hermes
  logic — just an extra supervised `tailscaled`.
- **`container run`** (not `container machine`) for real `--volume` bind mounts;
  `--cap-add CAP_NET_ADMIN/CAP_NET_RAW` lets tailscaled create its TUN.
- **Portable**: no hardcoded paths/usernames — env vars with defaults from the current
  user/host, overridable via `.env`.

## Layout

```
image/      build context — Dockerfile + s6/tailscaled/{type,run}
lib/        common.sh — env-driven config + .env loader
scripts/    00–04, test.sh, migrate-data.sh, backup.sh, restore.sh,
            boot.sh, autostart-*.sh, builder-stop.sh
README.md  CLAUDE.md  ROADMAP.md  .env.example   (root: docs + config)
```

## Conventions

All work here is **scripted, idempotent, and documented** — no manual mutation of the
box. Updates and tests go through committed scripts; `scripts/test.sh` is the canonical
check. See [`CLAUDE.md`](CLAUDE.md) for the full rules.

## Run order

```bash
cp .env.example .env            # optional per-machine overrides
./scripts/00-prereqs.sh         # container CLI up
./scripts/01-build.sh           # build local/hermes-box:latest from image/
./scripts/migrate-data.sh       # ONE-TIME: consolidate ~/.hermes + hermes-home (box stopped)
./scripts/02-run.sh             # run: Hermes gateway + Tailscale, with volumes + ports
./scripts/03-tailscale-up.sh    # open the printed URL to authenticate (first run only)
./scripts/test.sh               # canonical health check (10 checks)
```

Hermes UI/gateway: `http://localhost:9119`. Shell in the box:
`container exec -it hermes-box bash`, or over the tailnet: `ssh hermes@hermes-box`.

## Web (Caddy over the tailnet)

Caddy runs as an s6 service in the box, bound to the **tailnet IP only**, terminating
TLS with a **Tailscale-issued cert** (`tailscale cert`, `auto_https off`) — replicating
the Raspberry Pi setup. Apps stay on loopback; Caddy is the only network listener.

| URL | Serves |
|---|---|
| `https://<fqdn>/` | wiki (MkDocs static, from `wiki-site/_site`) |
| `https://<fqdn>:8443/` | Hermes dashboard (proxy → `127.0.0.1:9119`, Host/Origin rewrite) |

`<fqdn>` = the box's MagicDNS name (set `HERMES_BOX_TS_FQDN` in `.env`). The cert is
fetched at container start (refreshes on restart). Wiki content lives in the mounted
`hermes-home/wiki`; rebuild the static site with `mkdocs build` (mkdocs not yet baked
into the image). The two `sites/` (ownstack, tanglinlaw) are intentionally **not** hosted.

## Data layout (consolidated, backup-friendly)

```
~/AiInfra/hermes-box-data/         # = HERMES_BOX_DATA_ROOT
  .hermes/        ->  /opt/data        (Hermes state, was ~/.hermes)
  hermes-home/    ->  /home/nilushan   (work folder, was ~/AiInfra/hermes-home)
```
Tailscale identity lives in a **named volume** (`<name>-tsstate`), not a bind mount
(tailscaled chmods its state dir to 0700, which virtiofs rejects). It's re-authable,
so it's excluded from data backups.

## Backups

**Offsite (restic → Cloudflare R2)** — encrypted, versioned, the real backup:
```bash
cp cf.env.example cf.env           # fill CF_API_TOKEN (R2 Edit) + CF_ACCOUNT_ID (gitignored)
./scripts/cf-r2-setup.sh           # creates the R2 bucket + writes restic.env (S3 creds)
./scripts/restic-backup.sh         # init (first run) + backup + prune (7d/4w/6m retention)
./scripts/restic-snapshots.sh      # list snapshots + repo size
./scripts/restic-restore.sh [snap] [target]   # restore (default: latest -> ~/hermes-box-restore)
./scripts/restic-schedule-install.sh          # launchd: daily backup at 03:00 (uninstall: -uninstall.sh)
```
Cloudflare provisioning is scripted: `cf-r2-setup.sh` creates the bucket and derives
restic's S3 creds from a CF API token (Account > Workers R2 Storage > Edit) in
gitignored `cf.env`. Secrets live in `cf.env` / `restic.env` (both gitignored).

**Local (tar snapshot)** — quick stopgap on the same disk:
```bash
./scripts/backup.sh             # timestamped tar.gz into the backups dir
./scripts/restore.sh [archive]  # restore newest (or named); box must be stopped
```
Both exclude regenerable caches (`.cache .npm node_modules .playwright`). The Mac disk
is tight, so prefer restic→R2 over accumulating local snapshots.

## Configuration (all optional — see `.env.example`)

| Env var | Default | Meaning |
|---|---|---|
| `HERMES_BOX_USER` | `hermes` | SSH login user (the Hermes image's user) |
| `HERMES_BOX_NAME` | `hermes-box` | container name / default TS hostname |
| `HERMES_BOX_DATA_ROOT` | `~/AiInfra/hermes-box-data` | holds `.hermes/` + `hermes-home/` |
| `HERMES_BOX_BACKUP_DIR` | `~/AiInfra/hermes-box-backups` | snapshot destination |
| `HERMES_BOX_GATEWAY_PORT` / `_DASHBOARD_PORT` | `9119` / `8642` | published ports |
| `HERMES_BOX_PUID` / `_PGID` | `$(id -u)` / `$(id -g)` | Hermes file ownership |
| `HERMES_BOX_CPUS` / `_MEMORY` | `4` / `4G` | sizing |
| `HERMES_BOX_STATE_VOLUME` | `<name>-tsstate` | named volume for tailnet identity |

## Files

| File | What |
|---|---|
| `image/Dockerfile` | `FROM nousresearch/hermes-agent` + Tailscale + Caddy + s6 services |
| `image/s6/{tailscaled,caddy}/` | s6-overlay longrun services |
| `image/caddy/Caddyfile` | wiki (`:443`) + dashboard (`:8443`) over the tailnet |
| `lib/common.sh` | env-driven config + `.env` loader |
| `scripts/00`–`04` | prereqs / build / run / tailscale-up / verify |
| `scripts/migrate-data.sh` | one-time: consolidate existing data into the data root |
| `scripts/backup.sh` / `restore.sh` | snapshot / restore the data root |
| `scripts/test.sh` | canonical re-runnable health check |
| `scripts/boot.sh` + `autostart-*.sh` | launchd auto-start at login |
| `scripts/builder-stop.sh` / `builder-reset.sh` | stop / delete BuildKit (free RAM / disk) |
| `CLAUDE.md` / `ROADMAP.md` | conventions / plan + status |

## Auto-start on boot

A launchd LaunchAgent runs `scripts/boot.sh` at login (Apple `container` is
user-scoped, so this is a per-user agent, not a system daemon):

```bash
./scripts/autostart-install.sh     # box auto-starts at login from now on
./scripts/autostart-uninstall.sh   # stop auto-starting (does not stop the box)
```

`boot.sh` is idempotent: running → no-op; stopped → `container start`; missing →
`02-run.sh`. Logs to `autostart.log`. Note: a LaunchAgent runs at **login**, so on a
headless Mac mini enable auto-login (or stays-logged-in) for true post-reboot start.

## Notes

- **Volumes are real bind mounts** — edits on the Mac and in the box are the same files,
  instantly, both ways. (The earlier `container machine` + mutagen approach is in git
  history; `container machine` can only mount the Mac home, not arbitrary folders.)
- **Tailscale identity persists** in the named volume, so a restart/recreate reconnects
  (with Tailscale SSH) — no re-auth.
- **Hermes** runs via the image's s6-overlay (`main-hermes`, `dashboard`) with our added
  `tailscaled` service; gateway serves on 9119 (the dashboard UI is served there too).
- **⚠ Disk**: the Hermes image is large (several GB). Building the derived image needs
  real headroom — keep well clear of a full disk or `container build` fails to import
  (`failed to extract archive`). `./scripts/builder-stop.sh` and `container builder
  delete --force` reclaim the BuildKit cache (~8–11 GB).
- **One-time Tailscale ACL** (admin console → Access Controls) must allow SSH to your
  own machines:
  ```json
  "ssh": [{ "action": "accept", "src": ["autogroup:member"],
            "dst": ["autogroup:self"], "users": ["autogroup:nonroot", "root"] }]
  ```

## Teardown

```bash
container rm -f hermes-box        # stop the runtime (data is safe in the data root)
# To roll back to the old standalone Hermes: re-enable the disabled launchd agent
#   mv ~/Library/LaunchAgents/com.ownstack.hermes.plist.disabled ...plist  (note: it
#   expects data at the OLD ~/.hermes path, which migrate-data.sh moved)
```
