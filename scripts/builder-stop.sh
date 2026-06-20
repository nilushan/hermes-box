#!/usr/bin/env bash
# Optional utility — stop the BuildKit image builder to free its ~2 GB RAM when you
# are not building. Run MANUALLY when needed; this is deliberately NOT part of the
# numbered setup sequence and is NOT triggered automatically by any other script.
# The next `container build` (./01-build.sh) auto-starts the builder again.
source "$(dirname "$0")/../lib/common.sh"

echo "Builder status:"
container builder status 2>&1 || true
echo

if container builder status 2>/dev/null | grep -q running; then
  echo "Stopping the image builder..."
  container builder stop
  echo "Stopped. It will auto-start again on the next 'container build'."
else
  echo "Builder is not running; nothing to do."
fi
