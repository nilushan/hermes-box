# Hermes box

A minimal Ubuntu box on macOS (`container`) with Tailscale, reachable over the
tailnet via Tailscale SSH, with your work folder bind-mounted as the box's home.

Built on **`container run`** (not `container machine`) so it gets real `--volume`
bind mounts. Tailscale needs `CAP_NET_ADMIN`/`CAP_NET_RAW`, which `container run`
grants via `--cap-add`. There is no systemd; a small `entrypoint.sh` brings up
`tailscaled` and creates the box user at runtime.

Everything is **portable**: no hardcoded paths or usernames. Settings come from env
vars with defaults derived from the current user/host, overridable via `.env`.

## Layout

```
image/      build context — Dockerfile + entrypoint.sh
lib/        common.sh — env-driven config + .env loader
scripts/    lifecycle: 00–04, test.sh, builder-stop.sh
README.md  CLAUDE.md  .env.example   (root: docs + config)
```

## Conventions

All work here is **scripted, idempotent, and documented** — no manual mutation of the
box. Updates and tests go through committed scripts; `scripts/test.sh` is the canonical
check. See [`CLAUDE.md`](CLAUDE.md) for the full rules.

## Run order

```bash
cp .env.example .env            # optional: set HERMES_BOX_USER / HERMES_BOX_HOME / etc.
./scripts/00-prereqs.sh         # container CLI up
./scripts/01-build.sh           # build local/hermes-box:latest from image/
./scripts/02-run.sh             # container run with caps + volumes
./scripts/03-tailscale-up.sh    # open the printed URL to authenticate (first run only)
./scripts/04-verify.sh          # status + SSH from the Mac + prove the bind mount
./scripts/test.sh               # canonical health check
```

Get a shell in the box: `container exec -it <name> bash`, or over the tailnet:
`ssh <user>@<hostname>`.

## Configuration (all optional — see `.env.example`)

| Env var | Default | Meaning |
|---|---|---|
| `HERMES_BOX_USER` | `$(id -un)` | box username |
| `HERMES_BOX_UID` / `_GID` | `$(id -u)` / `$(id -g)` | so mounted files match owners |
| `HERMES_BOX_HOME` | `$HOME/hermes-home` | host folder mounted as the box home |
| `HERMES_BOX_NAME` | `hermes-box` | container name / default TS hostname |
| `HERMES_BOX_TS_HOSTNAME` | `=NAME` | tailnet/MagicDNS hostname |
| `HERMES_BOX_IMAGE` | `local/hermes-box:latest` | image tag |
| `HERMES_BOX_CPUS` / `_MEMORY` | `4` / `4G` | sizing |
| `HERMES_BOX_STATE_VOLUME` | `<name>-tsstate` | named volume for tailnet identity |

## Files

| File | What |
|---|---|
| `image/Dockerfile` | Ubuntu 24.04 + Tailscale + entrypoint (no user/path baked in) |
| `image/entrypoint.sh` | creates box user from env, starts `tailscaled`, holds open |
| `lib/common.sh` | env-driven config + `.env` loader |
| `scripts/00`–`04` | prereqs / build / run / tailscale-up / verify |
| `scripts/test.sh` | canonical re-runnable health check (run after any change) |
| `scripts/builder-stop.sh` | optional/manual: stop the BuildKit builder to free ~2 GB RAM |
| `CLAUDE.md` | working conventions (scripted/portable/documented) |

## Notes

- **Volumes are real bind mounts** — edits on the Mac and in the box are the same
  files, instantly, both ways. (The earlier `container machine` + mutagen approach
  is in git history; `container machine` can only mount the Mac home, not arbitrary
  folders, which is why this rebuild moved to `container run`.)
- **Tailscale identity persists** in the named volume `HERMES_BOX_STATE_VOLUME`, so
  after a restart/recreate the box reconnects (with Tailscale SSH) — no re-auth.
- **One-time Tailscale ACL** (admin console → Access Controls) must allow SSH to your
  own machines:
  ```json
  "ssh": [{ "action": "accept", "src": ["autogroup:member"],
            "dst": ["autogroup:self"], "users": ["autogroup:nonroot", "root"] }]
  ```

## Teardown

```bash
container rm -f hermes-box      # or your $HERMES_BOX_NAME
# tailnet device lingers in the admin console; remove it there if you want the name back
```
