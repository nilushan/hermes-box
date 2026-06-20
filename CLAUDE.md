# hermes-box — working conventions

Rules for all work in this repo (the hermes-box container/VM setup). These are
binding: follow them unless the user explicitly says otherwise for a given task.

## 1. Scripted, reproducible, documented — no manual mutation

- Every change to the box (build, run, config, update, fix) is made by a
  **committed, idempotent script** in this repo — never by ad-hoc manual commands.
- Setup scripts are **numbered** for order (`00-`, `01-`, …) and safe to re-run.
- **Testing is scripted too**: `./test.sh` is the canonical, non-destructive check.
  Run it after any change and confirm it passes.
- **Document** every script: a header comment explaining what/why, plus a row in
  `README.md`.
- The only acceptable manual commands are genuine **one-offs that never need to run
  again** (a throwaway diagnostic, a one-time admin-console click). If a command
  could ever be needed again, it belongs in a script. When in doubt, script it.
- If a one-off *was* required, note it (in the commit message or README) so it's not
  lost.

## 2. Portable — no hardcoded paths or usernames

- All settings are env vars with defaults derived from the current user/host
  (`lib.sh`), overridable via a gitignored `.env` (`.env.example` is the template).
- Nothing user- or path-specific is baked into the image; the box user is created at
  runtime from env.

## 3. Workflow for any change

1. Edit/add the relevant script(s).
2. Run them.
3. Run `./test.sh`; confirm all checks pass.
4. Update `README.md` / docs.
5. Commit — small, focused, message explains the *why*.

## 4. Architecture (current)

- `container run` (not `container machine`) → real `--volume` bind mounts.
- Tailscale via `--cap-add CAP_NET_ADMIN CAP_NET_RAW`; `entrypoint.sh` creates the
  user and starts `tailscaled` (no systemd). Tailscale state in a **named volume**
  (bind mounts break its state-store `chmod`).
