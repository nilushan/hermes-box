# Operations manual

Day-to-day operation of the Hermes box: data layout, backups, configuration
reference, auto-start, and troubleshooting notes. For the high-level overview and
quick start, see the [README](../README.md). For the working conventions that govern
changes to this repo, see [`CLAUDE.md`](../CLAUDE.md).

## Web access (Caddy over the tailnet)

Caddy runs as an s6 service in the box, bound to the **tailnet IP only**, terminating
TLS with a **Tailscale-issued cert** (`tailscale cert`, `auto_https off`). Apps stay on
loopback; Caddy is the only network listener.

| URL | Serves |
|---|---|
| `https://<fqdn>/` | wiki (MkDocs static, from `wiki-site/_site`) |
| `https://<fqdn>:8443/` | Hermes dashboard (proxy → `127.0.0.1:9119`, Host/Origin rewrite) |

`<fqdn>` = the box's MagicDNS name (set `HERMES_BOX_TS_FQDN` in `.env`). The cert is
fetched at container start (refreshes on restart). Wiki content lives in the mounted
`hermes-home/wiki`; rebuild the static site with `mkdocs build` (mkdocs not yet baked
into the image). Any other static `sites/` in the work folder are intentionally **not**
hosted.

## Claude Code (in the box)

Claude Code is **baked into the image** at `/usr/local/bin/claude` (so a from-scratch box
has it), authenticated with the Claude **Max subscription** (OAuth). The login lives in
the persistent `/opt/data/.claude` volume — it survives recreates and is in the restic
backup (creds encrypted). A data-dir copy (`/opt/data/.local/bin/claude`), if present
from an earlier install, shadows the baked one via PATH; both work and share the login.

```bash
./scripts/claude-setup.sh   # install-if-missing + verify subscription auth
```
Auth is an interactive subscription login (can't be scripted). If it ever shows
"NOT authenticated":
```bash
container exec -it --user hermes hermes-box sh -lc 'export HOME=/opt/data; \
  /opt/data/.local/bin/claude'   # follow the login prompts (URL + code)
```

## Data layout (consolidated, backup-friendly)

```
~/AiInfra/hermes-box-data/         # = HERMES_BOX_DATA_ROOT
  .hermes/        ->  /opt/data        (Hermes state, was ~/.hermes)
  hermes-home/    ->  /home/hermes     (work folder; in-box path = HERMES_BOX_WORK_MOUNT)
```
Tailscale identity lives in a **named volume** (`<name>-tsstate`), not a bind mount
(tailscaled chmods its state dir to 0700, which virtiofs rejects). It's re-authable,
so it's excluded from data backups.

## Backups

**Offsite (restic → Cloudflare R2)** — encrypted, versioned, the real backup:
```bash
cp cf.env.example cf.env           # fill CF_API_TOKEN (R2 Edit) + CF_ACCOUNT_ID (gitignored)
./scripts/backup/cf-r2-setup.sh           # creates the R2 bucket + writes restic.env (S3 creds)
./scripts/backup/restic-backup.sh         # init (first run) + backup + prune (7d/4w/6m retention)
./scripts/backup/restic-snapshots.sh      # list snapshots + repo size
./scripts/backup/restic-restore.sh [snap] [target]   # restore (default: latest -> ~/hermes-box-restore)
./scripts/backup/restic-schedule-install.sh          # launchd: daily backup at 03:00 (uninstall: -uninstall.sh)
```
Cloudflare provisioning is scripted: `cf-r2-setup.sh` creates the bucket and derives
restic's S3 creds from a CF API token (Account > Workers R2 Storage > Edit) in
gitignored `cf.env`. Secrets live in `cf.env` / `restic.env` (both gitignored).

Run / inspect anytime (the daily timer also runs `restic-backup.sh` at 03:00).
`restic.sh` is a wrapper that loads `restic.env` so you don't have to source it:
```bash
./scripts/backup/restic-backup.sh        # back up now
./scripts/backup/restic.sh snapshots     # list backups
./scripts/backup/restic.sh ls latest     # list files in the latest snapshot
./scripts/backup/restic.sh stats         # repo size
./scripts/backup/restic.sh find <name>   # locate a file across snapshots
```
(Plain `restic ...` fails with "specify repository location" unless `restic.env` is
sourced — that's what `restic.sh` does for you.)
Note: in the **R2 console you won't see your files** — restic stores everything as
encrypted, deduplicated pack files under `data/` (hash names, ~16 MB each), plus
`index/`, `snapshots/`, `keys/`, `config`. Browse contents via `restic ls`, not the
console. Keep `RESTIC_PASSWORD` (in `restic.env`) safe — without it the repo is
unrecoverable.

**Local (tar snapshot)** — quick stopgap on the same disk:
```bash
./scripts/backup/backup.sh             # timestamped tar.gz into the backups dir
./scripts/backup/restore.sh [archive]  # restore newest (or named); box must be stopped
```
Both exclude regenerable caches (`.cache .npm node_modules .playwright`). The Mac disk
is tight, so prefer restic→R2 over accumulating local snapshots.

## Configuration (all optional — see `.env.example`)

| Env var | Default | Meaning |
|---|---|---|
| `HERMES_BOX_USER` | `hermes` | SSH login user (the Hermes image's user) |
| `HERMES_BOX_WORK_MOUNT` | `/home/$BOX_USER` | in-box mount path for the work folder |
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
| `image/Dockerfile` | `FROM nousresearch/hermes-agent` + Tailscale + Caddy + Claude Code + s6 |
| `image/s6/{tailscaled,caddy}/` | s6-overlay longrun services |
| `image/caddy/Caddyfile` | wiki (`:443`) + dashboard (`:8443`) over the tailnet |
| `lib/common.sh` | env-driven config + `.env` loader |
| `scripts/00`–`04` | prereqs / build / run / tailscale-up / verify |
| `scripts/migrate-data.sh` | one-time: consolidate existing data into the data root |
| `scripts/backup/backup.sh` / `restore.sh` | local tar snapshot / restore of the data root |
| `scripts/backup/cf-r2-setup.sh` | create the R2 bucket + derive restic S3 creds (from `cf.env`) |
| `scripts/backup/restic-backup.sh` / `restic-restore.sh` / `restic-snapshots.sh` | offsite backup to R2 |
| `scripts/backup/restic.sh` | wrapper: run any `restic` command with creds loaded |
| `scripts/backup/restic-schedule-install.sh` / `-uninstall.sh` | launchd daily restic backup |
| `scripts/claude-setup.sh` | install/verify Claude Code (subscription) in the box |
| `scripts/test.sh` | canonical re-runnable health check |
| `scripts/autostart/{boot,install,uninstall}.sh` | launchd auto-start at login |
| `scripts/builder/{stop,reset}.sh` | stop / delete BuildKit (free RAM / disk) |
| `CLAUDE.md` / `ROADMAP.md` | conventions / plan + status |

## Auto-start on boot

A launchd LaunchAgent runs `scripts/autostart/boot.sh` at login (Apple `container` is
user-scoped, so this is a per-user agent, not a system daemon):

```bash
./scripts/autostart/install.sh     # box auto-starts at login from now on
./scripts/autostart/uninstall.sh   # stop auto-starting (does not stop the box)
```

`boot.sh` is idempotent: running → no-op; stopped → `container start`; missing →
`02-run.sh`. Logs to `autostart.log`. Note: a LaunchAgent runs at **login**, so on a
headless Mac mini enable auto-login (or stays-logged-in) for true post-reboot start.

## Notes & troubleshooting

- **Volumes are real bind mounts** — edits on the Mac and in the box are the same files,
  instantly, both ways. (The earlier `container machine` + mutagen approach is in git
  history; `container machine` can only mount the Mac home, not arbitrary folders.)
- **Tailscale identity persists** in the named volume, so a restart/recreate reconnects
  (with Tailscale SSH) — no re-auth.
- **Hermes** runs via the image's s6-overlay (`main-hermes`, `dashboard`) with our added
  `tailscaled` service; gateway serves on 9119 (the dashboard UI is served there too).
- **⚠ Disk**: the Hermes image is large (several GB). Building the derived image needs
  real headroom — keep well clear of a full disk or `container build` fails to import
  (`failed to extract archive`). `./scripts/builder/stop.sh` and `container builder
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
```
