#!/bin/bash
# Clone vendor dependencies (symlinks in commands/ point here)

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENDOR_DIR="$SCRIPT_DIR/../vendor"

mkdir -p "$VENDOR_DIR"

# claude-workflow - planning and execution commands
if [ ! -d "$VENDOR_DIR/claude-workflow" ]; then
  echo "Cloning claude-workflow..."
  git clone https://github.com/sbusso/claude-workflow.git "$VENDOR_DIR/claude-workflow"
else
  echo "claude-workflow already exists (run 'git -C $VENDOR_DIR/claude-workflow pull' to update)"
fi

echo "Done. Symlinks in commands/ and contexts/ should now resolve."
