#!/usr/bin/env bash
# Step 0 — verify the `container` CLI is installed and the service is running.
source "$(dirname "$0")/lib.sh"

echo "container CLI: $(container --version)"
echo "Ensuring container system is started..."
container system start 2>/dev/null || true
container system status
