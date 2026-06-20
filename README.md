# Hermes box — Phase 1

Build a minimal Ubuntu container machine on macOS (`container`), bring up
Tailscale, and SSH into it over the tailnet. Nothing else (no Hermes yet).

Everything is reproducible from this folder. The only non-reproducible step is
the interactive Tailscale auth (Step 4), which is inherent — it needs your login.

## Artifacts

| File                   | Step | What it does                                                  |
|------------------------|------|--------------------------------------------------------------|
| `Dockerfile`           | 1    | Ubuntu 24.04 + ssh + Tailscale machine image (rebuild source)|
| `lib.sh`               | —    | Shared config (machine name, cpus, memory, user)             |
| `00-prereqs.sh`        | 0    | Verify `container` CLI + start the service                    |
| `01-build.sh`          | 1    | `container build -t local/hermes-box:latest .`               |
| `02-create-machine.sh` | 2    | Create + boot the machine (4 CPU, 4G, home-mount=ro)         |
| `03-tailscale-up.sh`   | 4    | `tailscale up --ssh` inside the box (interactive auth)        |
| `04-verify.sh`         | 6    | Tailscale status + SSH in from the Mac over the tailnet       |
| `05-detach-home.sh`    | +    | `home-mount=none` — stop mounting the Mac home (`/Users`)     |
| `06-setup-sync-ssh.sh` | +    | keyed OpenSSH transport on the bridge for mutagen            |
| `07-sync-box-home.sh`  | +    | mutagen two-way sync `./box-home` ↔ box `/home/<user>`        |

## Run order

```bash
./00-prereqs.sh
./01-build.sh
./02-create-machine.sh
./03-tailscale-up.sh      # open the printed URL to authenticate
./04-verify.sh
```

To get an interactive shell in the box at any point (Step 3):

```bash
container machine run -n hermes-box
```

## Notes / deviations from the original plan

- **Box user is `nilushansilva`, not `nilushan`.** The machine auto-provisions a
  user matching the Mac account, which is `nilushansilva`. SSH target is
  `nilushansilva@hermes-box`.
- **`home-mount=ro` is set at create time** (`--home-mount ro`) rather than via a
  post-boot `set` + restart. Same result, fewer steps, and the box's view of the
  Mac home (including `~/.ssh`) is read-only from first boot.
- **Memory = 4G** because this host has 8 GB. Bump it on a 16 GB machine.
- **`unminimize`** is guarded in the Dockerfile: on Ubuntu 24.04 it ships as a
  separate package and is absent from the minimized base image, so the build
  installs it if possible and skips it otherwise instead of failing.

## Home directory: detached Mac home + synced folder

`/Users` is **no longer mounted** into the box (`home-mount=none`). The box uses its
own internal `/home/<user>` (in the machine rootfs, persists across restarts).

`container machine` **cannot bind-mount an arbitrary host folder** — its only host
mount is the Mac home, as `ro`/`rw`/`none` (confirmed in the CLI and the machine's
`boot-config.json`). `container run` *does* support `--volume`, but it can't run our
systemd box (`/sbin/init` exits immediately). So instead of a bind mount we use a
**mutagen two-way sync** between `./box-home` (on the Mac) and the box's `/home/<user>`.

Transport detail: mutagen installs its agent via SFTP then `chmod +x`. Tailscale
SSH's SFTP server ignores `chmod`, so the agent stays non-executable. We therefore
sync over the box's **real OpenSSH server on the host↔VM bridge** (port 22, keyed,
sub-millisecond, no Tailscale involved). Tailscale SSH on the tailnet is untouched
and remains the path for remote interactive logins.

```bash
./06-setup-sync-ssh.sh     # one-time: key + authorized_keys + ssh-config alias
./07-sync-box-home.sh      # create/refresh the mutagen session
mutagen sync list          # check status
mutagen sync monitor hermes-box-home
```

**The bridge IP changes when the machine restarts.** Both scripts re-resolve it from
`container machine inspect` into the managed `hermes-box-sync` ssh-config alias, so
after any machine restart just re-run `./07-sync-box-home.sh` (it refreshes the alias
and the mutagen session reconnects; `HostKeyAlias` keeps `known_hosts` stable).

## One-time manual step — Tailscale ACL (Step 5)

Tailscale SSH is gated by an ACL rule. In the admin console
(<https://login.tailscale.com/admin/acls>) ensure an `ssh` block like:

```json
"ssh": [
  {
    "action": "accept",
    "src":    ["autogroup:member"],
    "dst":    ["autogroup:self"],
    "users":  ["autogroup:nonroot", "root"]
  }
]
```

This is the standard "let me SSH into my own machines" rule. Without it,
`04-verify.sh`'s SSH will be refused.

## Teardown

```bash
mutagen sync terminate hermes-box-home   # stop the sync first
container machine stop hermes-box
container machine delete hermes-box
```
