#!/usr/bin/env bash
# cleanup-test-repo.sh — Removes the test repo created by setup-test-repo.sh
# Safety: only deletes directories that contain the sentinel file and are under /tmp/.
set -euo pipefail

REPO_DIR="${1:-/tmp/ccautomated-test-repo}"

if [ ! -d "$REPO_DIR" ]; then
  echo "Nothing to clean: $REPO_DIR does not exist"
  exit 0
fi

if [ ! -f "$REPO_DIR/.ccautomated-test-repo" ]; then
  echo "ERROR: $REPO_DIR is not a CCAutomated test repo (missing sentinel file). Refusing to delete."
  exit 1
fi

case "$REPO_DIR" in
  /tmp/*)
    rm -rf "$REPO_DIR"
    echo "Cleaned up: $REPO_DIR"
    ;;
  *)
    echo "ERROR: $REPO_DIR is not under /tmp/. Refusing to delete."
    exit 1
    ;;
esac
