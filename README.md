# Hermes box

> Self-hosted, fully scripted runtime for the [Hermes](https://hub.docker.com/r/nousresearch/hermes-agent)
> AI agent on macOS — reachable over a private [Tailscale](https://tailscale.com) tailnet, with
> TLS-fronted web access and encrypted offsite backups. Everything (build, run, backup, auto-start)
> is an idempotent, committed shell script; nothing is configured by hand.

**The box *is* the Hermes runtime.** A single container on macOS (Apple's `container`
CLI) runs the Hermes gateway and `tailscaled` side by side, joined to a private tailnet
and reachable over Tailscale SSH. Its state and work folder are bind-mounted from one
consolidated, backup-friendly data root, and the whole lifecycle — build, run, back up,
auto-start at login — is driven by numbered, re-runnable scripts.

## Highlights

- **One image, supervised properly.** `FROM nousresearch/hermes-agent`, with Tailscale
  and Caddy added as **s6-overlay** services alongside Hermes' own — no rewrite of the
  upstream image, just extra supervised processes.
- **Private by default.** Caddy is the only network listener and binds to the **tailnet
  IP only**, terminating TLS with a Tailscale-issued cert. The apps stay on loopback;
  the box is never exposed to the public internet.
- **Reproducible & portable.** No hardcoded paths or usernames — every setting is an env
  var with a sensible default derived from the current user/host, overridable via a
  gitignored `.env`. A from-scratch machine comes up from the scripts alone.
- **Durable.** Tailscale identity persists in a named volume (survives recreates);
  encrypted, versioned offsite backups go to Cloudflare R2 via restic on a daily timer.
- **Self-checking.** `scripts/test.sh` is a single non-destructive health check (container
  up, mounts live, gateway responding, SSH + HTTPS over the tailnet) — run after any change.

## Architecture

```mermaid
flowchart TB
  user["👤 You — laptop / phone"]
  tsnet{{"🔒 Tailscale tailnet<br/>identity · MagicDNS · WireGuard"}}
  r2[("☁️ Cloudflare R2<br/>encrypted backup bucket")]

  subgraph host["🖥️ macOS host"]
    direction TB
    local["localhost:9119 / :8642<br/>(host-only, --publish)"]

    subgraph dataroot["📁 data root — ~/AiInfra/hermes-box-data"]
      d_hermes[".hermes/ — Hermes state"]
      d_home["hermes-home/ — work folder + wiki"]
    end
    tsvol[("📦 named volume<br/>hermes-box-tsstate")]

    restic["🔐 restic (on host)"]
    timer["⏰ launchd — daily 03:00<br/>+ boot.sh at login"]

    subgraph container["📦 Apple container 'hermes-box' — container run"]
      direction TB
      subgraph s6["s6-overlay — supervises every service"]
        hermes["Hermes gateway + dashboard<br/>127.0.0.1:9119"]
        caddy["Caddy reverse proxy<br/>binds tailnet IP only<br/>:443 wiki · :8443 dashboard"]
        tailscaled["tailscaled<br/>CAP_NET_ADMIN/RAW → TUN"]
        claude["Claude Code (baked in)"]
      end
    end
  end

  %% volume mounts (dotted)
  d_hermes -. "bind → /opt/data" .-> hermes
  d_home -. "bind → /home/hermes" .-> hermes
  tsvol -. "named vol → /var/lib/tailscale" .-> tailscaled

  %% inside the box (solid)
  caddy -->|"reverse proxy (loopback)"| hermes
  caddy -. "tailscale cert (TLS)" .-> tailscaled
  tailscaled <-->|"WireGuard mesh"| tsnet
  local -. "published ports" .-> hermes

  %% secure access (thick)
  user <-->|"join tailnet (SSO identity)"| tsnet
  user == "Tailscale SSH — ssh hermes@hermes-box" ==> tailscaled
  user == "HTTPS :443 / :8443 over tailnet" ==> caddy

  %% backups (thick)
  timer == triggers ==> restic
  restic -. "read data root" .-> dataroot
  restic == "encrypt · dedup · upload" ==> r2

  classDef ext fill:#e8f0fe,stroke:#1a73e8,color:#174ea6;
  classDef store fill:#fff4e5,stroke:#f59e0b,color:#92400e;
  classDef svc fill:#e6f4ea,stroke:#34a853,color:#137333;
  classDef tool fill:#fce8e6,stroke:#ea4335,color:#a50e0e;
  class user,tsnet,r2 ext;
  class d_hermes,d_home,tsvol store;
  class hermes,caddy,tailscaled,claude svc;
  class restic,timer,local tool;
  style container fill:#eef2ff,stroke:#6366f1,stroke-width:2px;
  style s6 fill:#f5f3ff,stroke:#818cf8;
  style host fill:#fafafa,stroke:#9ca3af;
  style dataroot fill:#fff8ef,stroke:#f59e0b;
```

**Reading the diagram** — dotted edges are mount points (host data → in-box paths),
thick edges are the security-sensitive flows: all access arrives over the encrypted
Tailscale tailnet (SSH to `tailscaled`, HTTPS to Caddy — never a public port), and
backups are encrypted on the host by restic before they leave for Cloudflare R2.

`container run` (not `container machine`) is used deliberately: it gives real `--volume`
bind mounts of arbitrary host folders, and `--cap-add CAP_NET_ADMIN/CAP_NET_RAW` lets
`tailscaled` create its TUN device.

## Quick start

```bash
cp .env.example .env            # optional per-machine overrides
./scripts/00-prereqs.sh         # container CLI up
./scripts/01-build.sh           # build local/hermes-box:latest from image/
./scripts/migrate-data.sh       # ONE-TIME: consolidate ~/.hermes + hermes-home (box stopped)
./scripts/02-run.sh             # run: Hermes gateway + Tailscale, with volumes + ports
./scripts/03-tailscale-up.sh    # open the printed URL to authenticate (first run only)
./scripts/test.sh               # canonical health check
```

Then reach Hermes at `http://localhost:9119`, shell in with
`container exec -it hermes-box bash`, or over the tailnet with `ssh hermes@hermes-box`.
Web access (wiki + dashboard) is served by Caddy over HTTPS on the tailnet — see the
[operations manual](docs/OPERATIONS.md#web-access-caddy-over-the-tailnet).

## Repository layout

```
image/      build context — Dockerfile + s6/{tailscaled,caddy}/ + caddy/Caddyfile
lib/        common.sh — env-driven config + .env loader
scripts/    00–04, test.sh, migrate-data.sh           # lifecycle
  backup/     backup.sh restore.sh cf-r2-setup.sh restic*.sh restic-schedule-*.sh
  autostart/  boot.sh install.sh uninstall.sh         # launchd at login
  builder/    stop.sh reset.sh                         # BuildKit RAM/disk
docs/       OPERATIONS.md — backups, config, auto-start, troubleshooting
.env.example  cf.env.example  restic.env.example       # templates (real ones gitignored)
CLAUDE.md  ROADMAP.md
```

## Conventions

All work here is **scripted, idempotent, and documented** — no manual mutation of the
box. Every change goes through a committed script, `scripts/test.sh` is the canonical
check, and secrets live only in gitignored `.env` / `cf.env` / `restic.env`. The full
rules are in [`CLAUDE.md`](CLAUDE.md).

## Documentation

- [**Operations manual**](docs/OPERATIONS.md) — data layout, backups (restic → R2),
  full configuration reference, Claude Code in the box, auto-start, troubleshooting,
  and teardown.
- [`CLAUDE.md`](CLAUDE.md) — working conventions for changes to this repo.
- [`ROADMAP.md`](ROADMAP.md) — what's done and what's next.

## License

[MIT](LICENSE)
