#!/bin/bash
# Clone the vendored ai-software-architect fork at PIN (symlinks in skills/
# point into it), or check an existing clone. Never changes an existing clone.
#
# PIN moves only after the review-and-bump procedure in SETUP.md
# ("Vendor dependencies").

set -euo pipefail

REPO_URL="https://github.com/bettison-org/ai-software-architect.git"
PIN="bf56a76760a6f1ea1fec0fbe0c116cdca8ac034a"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENDOR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/vendor"
CLONE_DIR="$VENDOR_DIR/ai-software-architect"

fail() {
  echo "vendor-setup: $*" >&2
  exit 1
}

clone_at_pin() {
  mkdir -p "$VENDOR_DIR"
  tmp_dir="$(mktemp -d "$VENDOR_DIR/.ai-software-architect.XXXXXX")"
  trap 'rm -rf "$tmp_dir"' EXIT
  trap 'exit 1' INT TERM HUP

  git clone --quiet --no-checkout -- "$REPO_URL" "$tmp_dir"
  git -C "$tmp_dir" cat-file -e "$PIN^{commit}" 2>/dev/null \
    || fail "PIN $PIN is not a commit in $REPO_URL"
  # The full ref name: a tag called origin/main would otherwise take precedence.
  git -C "$tmp_dir" merge-base --is-ancestor "$PIN" refs/remotes/origin/main \
    || fail "PIN $PIN is not on main in $REPO_URL"
  git -C "$tmp_dir" checkout --quiet --detach "$PIN"
  [ "$(git -C "$tmp_dir" rev-parse HEAD)" = "$PIN" ] \
    || fail "HEAD after checkout is not PIN $PIN"

  mv "$tmp_dir" "$CLONE_DIR"
  trap - EXIT
  echo "vendor-setup: cloned ai-software-architect at $PIN"
}

check_clone() {
  local ok=1 origin remote_cmd changes head

  [ -e "$CLONE_DIR/.git" ] \
    || fail "$CLONE_DIR exists but is not a git clone; move it aside and re-run"

  origin="$(git -C "$CLONE_DIR" remote get-url origin 2>/dev/null || true)"
  if [ "$origin" != "$REPO_URL" ] && [ "$origin" != "${REPO_URL%.git}" ]; then
    ok=0
    remote_cmd="set-url"
    [ -n "$origin" ] || remote_cmd="add"
    echo "vendor-setup: origin is '${origin:-none}', not the fork. Point it at the fork:" >&2
    echo "  git -C \"$CLONE_DIR\" remote $remote_cmd origin $REPO_URL" >&2
  fi

  # --no-optional-locks stops status refreshing (writing) the clone's index.
  if ! changes="$(git --no-optional-locks -C "$CLONE_DIR" status --porcelain)" || [ -n "$changes" ]; then
    ok=0
    echo "vendor-setup: the working tree has uncommitted changes. Review them, then stash them:" >&2
    echo "  git -C \"$CLONE_DIR\" status" >&2
    echo "  git -C \"$CLONE_DIR\" stash push --include-untracked" >&2
  fi

  head="$(git -C "$CLONE_DIR" rev-parse --verify --quiet HEAD || true)"
  if [ "$head" != "$PIN" ]; then
    ok=0
    echo "vendor-setup: HEAD is ${head:-none}, not PIN $PIN. Move it to PIN:" >&2
    echo "  git -C \"$CLONE_DIR\" fetch origin" >&2
    echo "  git -C \"$CLONE_DIR\" switch --detach $PIN" >&2
  fi

  [ "$ok" = 1 ] || fail "left $CLONE_DIR unchanged"
  echo "vendor-setup: ai-software-architect OK at $PIN"
}

[[ "$PIN" =~ ^[0-9a-f]{40}$ ]] \
  || fail "PIN must be a full 40-character lowercase hex commit SHA, not '$PIN'"

if [ -e "$CLONE_DIR" ] || [ -L "$CLONE_DIR" ]; then
  check_clone
else
  clone_at_pin
fi
