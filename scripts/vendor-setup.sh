#!/bin/bash
# Clone vendor dependencies (symlinks in skills/ point here)

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENDOR_DIR="$SCRIPT_DIR/../vendor"

mkdir -p "$VENDOR_DIR"

# ai-software-architect - architecture review skills
if [ ! -d "$VENDOR_DIR/ai-software-architect" ]; then
  echo "Cloning ai-software-architect..."
  git clone https://github.com/codenamev/ai-software-architect.git "$VENDOR_DIR/ai-software-architect"
else
  echo "ai-software-architect already exists (run 'git -C $VENDOR_DIR/ai-software-architect pull' to update)"
fi

echo "Done. Symlinks in skills/ should now resolve."
