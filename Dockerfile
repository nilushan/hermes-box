FROM ubuntu:24.04

# Tailscale + basic tooling. No systemd: this image runs under `container run`,
# where a small entrypoint supervises tailscaled directly. `container run` gives us
# real --volume bind mounts (which `container machine` cannot) at the cost of no
# systemd, so we bring services up ourselves.
#
# The box user is created at RUNTIME by the entrypoint from BOX_USER/BOX_UID/BOX_GID
# env vars — nothing user- or path-specific is baked into the image, so the same
# image is portable across accounts and machines.
RUN apt-get update && apt-get install -y \
      ca-certificates curl iproute2 iputils-ping sudo vim-tiny openssh-client \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://tailscale.com/install.sh | sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
