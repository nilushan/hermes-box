#!/usr/bin/env bash
# Reclaim disk by deleting the BuildKit builder (and its multi-GB cache). Safe: the
# next `container build` recreates it. Run this before a big build when disk is tight
# (the Hermes-based image is large and `container build` needs headroom to import,
# else it fails with "failed to extract archive").
source "$(dirname "$0")/../../lib/common.sh"

echo "Disk before:"; df -h /System/Volumes/Data 2>/dev/null | awk 'NR==1||/Data/'
echo "Deleting BuildKit builder (force)..."
container builder delete --force 2>&1 | tail -2 || true
echo "Disk after:"; df -h /System/Volumes/Data 2>/dev/null | awk 'NR==1||/Data/'
