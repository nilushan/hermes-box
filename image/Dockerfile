# The box IS the Hermes runtime: extend the official Hermes image with Tailscale,
# supervised by the image's existing s6-overlay (Debian 13 base). `container run`
# gives real --volume bind mounts; --cap-add lets tailscaled create its TUN.
FROM nousresearch/hermes-agent:latest

# Tailscale static binaries (container-friendly; no systemd/apt-postinst issues),
# plus the net tools tailscaled needs to manage the TUN/firewall.
ARG TAILSCALE_VERSION=1.98.4
ARG TARGETARCH=arm64
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates iptables iproute2 \
 && curl -fsSL "https://pkgs.tailscale.com/stable/tailscale_${TAILSCALE_VERSION}_${TARGETARCH}.tgz" -o /tmp/ts.tgz \
 && tar -xzf /tmp/ts.tgz -C /tmp \
 && mv "/tmp/tailscale_${TAILSCALE_VERSION}_${TARGETARCH}/tailscale"  /usr/local/bin/tailscale \
 && mv "/tmp/tailscale_${TAILSCALE_VERSION}_${TARGETARCH}/tailscaled" /usr/local/bin/tailscaled \
 && rm -rf /tmp/ts.tgz "/tmp/tailscale_${TAILSCALE_VERSION}_${TARGETARCH}" /var/lib/apt/lists/*

# Add tailscaled as an s6-supervised longrun service alongside Hermes (main-hermes,
# dashboard). It restarts if it dies; state lives in the /var/lib/tailscale volume.
COPY s6/tailscaled/type /etc/s6-overlay/s6-rc.d/tailscaled/type
COPY s6/tailscaled/run  /etc/s6-overlay/s6-rc.d/tailscaled/run
RUN chmod +x /etc/s6-overlay/s6-rc.d/tailscaled/run \
 && touch /etc/s6-overlay/s6-rc.d/user/contents.d/tailscaled

# Entrypoint (/init) and CMD are inherited from the Hermes image; we pass
# `gateway run` at `container run` time, same as run-hermes.sh.
