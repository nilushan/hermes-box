# hermes-box — working conventions

Rules for all work in this repo (the hermes-box container/VM setup). These are
binding: follow them unless the user explicitly says otherwise for a given task.

## 0. Layout

```
image/    build context: Dockerfile (FROM nousresearch/hermes-agent + Tailscale)
          + s6/tailscaled/ (s6-overlay service)
lib/      common.sh — env-driven config + .env loader
scripts/  00–04, test.sh, migrate-data.sh, backup.sh, restore.sh,
          boot.sh, autostart-*.sh, builder-stop.sh
```
Scripts source config via `source "$(dirname "$0")/../lib/common.sh"`. Run scripts as
`./scripts/<name>.sh` from the repo root.

## 1. Scripted, reproducible, documented — no manual mutation

- Every change to the box (build, run, config, update, fix) is made by a
  **committed, idempotent script** in this repo — never by ad-hoc manual commands.
- Lifecycle scripts live in `scripts/`, **numbered** for order (`00-`, `01-`, …) and
  safe to re-run.
- **Testing is scripted too**: `scripts/test.sh` is the canonical, non-destructive
  check. Run it after any change and confirm it passes.
- **Document** every script: a header comment explaining what/why, plus a row in
  `README.md`.
- The only acceptable manual commands are genuine **one-offs that never need to run
  again** (a throwaway diagnostic, a one-time admin-console click). If a command
  could ever be needed again, it belongs in a script. When in doubt, script it.
- If a one-off *was* required, note it (in the commit message or README) so it's not
  lost.

## 2. Portable — no hardcoded paths or usernames

- All settings are env vars with defaults derived from the current user/host
  (`lib/common.sh`), overridable via a gitignored `.env` (`.env.example` is the template).
- Nothing user- or path-specific is baked into the image; the box user is created at
  runtime from env.

## 3. Workflow for any change

1. Edit/add the relevant script(s).
2. Run them.
3. Run `./scripts/test.sh`; confirm all checks pass.
4. Update `README.md` / docs.
5. Commit — small, focused, message explains the *why*.

## 4. Architecture (current)

- The box IS the Hermes runtime: image `FROM nousresearch/hermes-agent` + Tailscale as
  an s6-overlay service. One `container run` container = gateway + dashboard + tailscaled.
- `container run` (not `container machine`) → real `--volume` bind mounts;
  `--cap-add CAP_NET_ADMIN CAP_NET_RAW` for tailscaled's TUN.
- Data root `~/AiInfra/hermes-box-data/` (`.hermes`→/opt/data, `hermes-home`→/home/nilushan).
  Tailscale state in a **named volume** (bind mounts break its state-store `chmod`).
- Heads-up: the Hermes image is large — keep disk headroom or `01-build.sh` can't import.
