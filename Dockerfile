FROM ubuntu:24.04
ENV container=container

# Base packages for an interactive machine + ssh.
RUN apt-get update && apt-get install -y \
      dbus systemd systemd-sysv openssh-server \
      iproute2 iputils-ping curl ca-certificates sudo vim-tiny \
 && rm -rf /var/lib/apt/lists/*

# Restore full userland where available. On Ubuntu 24.04 `unminimize` ships as
# its own package and is not present in the minimized base image, so guard it
# rather than letting the build fail (the only change from Apple's recipe).
RUN apt-get update \
 && (command -v unminimize >/dev/null 2>&1 || apt-get install -y unminimize || true) \
 && (command -v unminimize >/dev/null 2>&1 && yes | unminimize || echo "unminimize unavailable; skipping") \
 && rm -rf /var/lib/apt/lists/*

# Tailscale installed now; you authenticate interactively at first boot.
RUN curl -fsSL https://tailscale.com/install.sh | sh

RUN >/etc/machine-id && >/var/lib/dbus/machine-id \
 && systemctl set-default multi-user.target \
 && systemctl enable ssh \
 && systemctl enable tailscaled \
 && systemctl mask \
      dev-hugepages.mount \
      sys-fs-fuse-connections.mount \
      systemd-update-utmp.service \
      console-getty.service
