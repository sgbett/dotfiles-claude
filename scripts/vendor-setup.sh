#!/bin/bash
# Clone vendor dependencies (symlinks in commands/ and skills/ point here)

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

# ai-software-architect - architecture review skills
if [ ! -d "$VENDOR_DIR/ai-software-architect" ]; then
  echo "Cloning ai-software-architect..."
  git clone https://github.com/codenamev/ai-software-architect.git "$VENDOR_DIR/ai-software-architect"
else
  echo "ai-software-architect already exists (run 'git -C $VENDOR_DIR/ai-software-architect pull' to update)"
fi

echo "Done. Symlinks in commands/, contexts/, and skills/ should now resolve."
