#!/usr/bin/env bash
# Step 1 — build the minimal Ubuntu machine image (ssh + Tailscale baked in).
source "$(dirname "$0")/lib.sh"
cd "$SCRIPT_DIR"

echo "Building ${IMAGE_TAG} from Dockerfile..."
container build -t "${IMAGE_TAG}" .
echo "Done. Image:"
container image list | grep -E "REPOSITORY|hermes-box" || container image list
