#!/usr/bin/env bash
# Step 1 — build the box image (Tailscale + entrypoint). Portable: no user/path
# baked in; the user is created at run time from env.
source "$(dirname "$0")/../lib/common.sh"

echo "Building ${IMAGE_TAG} from ${IMAGE_DIR}/Dockerfile..."
container build -t "${IMAGE_TAG}" "${IMAGE_DIR}"
echo "Done."
container image list | grep -E "REPOSITORY|${IMAGE_TAG%%:*}" || container image list
