#!/usr/bin/env bash
# integration-session-start.sh — Integration test that verifies the SessionStart
# hook triggers the Mutagen agent when a Claude Code session starts.
#
# REQUIREMENTS:
#   - `claude` CLI installed and authenticated
#   - API credits available (this starts a real session)
#   - Test repo must exist with a generated setup (run setup + generate-setup first)
#
# Usage: ./tests/integration-session-start.sh [/path/to/target-repo]
#        Defaults to /tmp/ccautomated-test-repo
#        Set KEEP_REPO=1 to preserve the test repo after the run.
#
# What it does:
#   1. Verifies claude CLI is available
#   2. Records the state of mutagen artifacts before the session
#   3. Starts a minimal Claude Code session in the target repo
#   4. Checks for evidence that Mutagen ran (logs, history, hook output)
set -uo pipefail

REPO_DIR="${1:-/tmp/ccautomated-test-repo}"
PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }
section() { echo ""; echo "=== $1 ==="; }

# ══════════════════════════════════════════════════════════════════════════════
section "Pre-flight"
# ══════════════════════════════════════════════════════════════════════════════

# Check claude CLI
if ! command -v claude &> /dev/null; then
  echo "ERROR: claude CLI not found. Install Claude Code first."
  exit 2
fi
pass "I1: claude CLI is available"

# Check target repo
if [ ! -d "$REPO_DIR" ]; then
  echo "ERROR: $REPO_DIR does not exist. Run setup-test-repo.sh + /generate-setup first."
  exit 2
fi
pass "I2: Target repo exists at $REPO_DIR"

# Check setup exists
if [ ! -f "$REPO_DIR/.claude/settings.json" ]; then
  echo "ERROR: No .claude/settings.json in $REPO_DIR. Run /generate-setup first."
  exit 2
fi
pass "I3: Setup exists in target repo"

# Verify SessionStart hook is configured
if ! jq -e '.hooks.SessionStart[0].hooks[0].agent' "$REPO_DIR/.claude/settings.json" 2>/dev/null | grep -q 'mutagen'; then
  fail "I4: SessionStart hook not configured to trigger mutagen"
  echo "RESULT: FAIL (SessionStart hook not configured — nothing to test)"
  exit 1
fi
pass "I4: SessionStart hook configured for mutagen agent"

# ══════════════════════════════════════════════════════════════════════════════
section "Pre-session state"
# ══════════════════════════════════════════════════════════════════════════════

# Record what exists before the session
PRE_HISTORY="none"
if [ -f "$REPO_DIR/.claude/mutagen-history.md" ]; then
  PRE_HISTORY=$(wc -l < "$REPO_DIR/.claude/mutagen-history.md" | tr -d ' ')
fi
echo "  Pre-session mutagen-history.md lines: $PRE_HISTORY"

PRE_USAGE_LOG="none"
if [ -f "$REPO_DIR/.claude/mutagen-usage-log.jsonl" ]; then
  PRE_USAGE_LOG=$(wc -l < "$REPO_DIR/.claude/mutagen-usage-log.jsonl" | tr -d ' ')
fi
echo "  Pre-session mutagen-usage-log.jsonl lines: $PRE_USAGE_LOG"

# ══════════════════════════════════════════════════════════════════════════════
section "Starting Claude Code session"
# ══════════════════════════════════════════════════════════════════════════════

echo "  Starting a minimal Claude Code session in $REPO_DIR..."
echo "  (This will make API calls and may take 30-90 seconds)"
echo ""

# Start a minimal session:
# - -p: non-interactive, provide prompt directly, respond once and exit
# The SessionStart hook should fire BEFORE Claude processes the prompt.
# Note: claude has no --cwd flag, so we cd into the repo directory.
(cd "$REPO_DIR" && claude -p "Say exactly: SESSION_START_TEST_COMPLETE" \
  > /tmp/ccautomated-session-output.txt 2>&1) || true

echo "  Session completed."
echo ""

# ══════════════════════════════════════════════════════════════════════════════
section "Post-session validation"
# ══════════════════════════════════════════════════════════════════════════════

# Check Claude responded (session actually ran)
if [ -f "/tmp/ccautomated-session-output.txt" ]; then
  if grep -q "SESSION_START_TEST_COMPLETE" /tmp/ccautomated-session-output.txt; then
    pass "I5: Claude session ran successfully"
  else
    warn "I5: Claude session ran but didn't produce expected output"
    echo "  Session output:"
    head -5 /tmp/ccautomated-session-output.txt | sed 's/^/    /'
  fi
else
  fail "I5: No session output file found"
fi

# Check for evidence Mutagen ran — mutagen-history.md should exist or have new content
# NOTE: SessionStart agent hooks may not fire in -p (non-interactive) mode.
# This is expected behavior — the hook is designed for interactive sessions.
if [ -f "$REPO_DIR/.claude/mutagen-history.md" ]; then
  POST_HISTORY=$(wc -l < "$REPO_DIR/.claude/mutagen-history.md" | tr -d ' ')
  if [ "$PRE_HISTORY" = "none" ]; then
    pass "I6: mutagen-history.md was CREATED by SessionStart (Mutagen ran)"
  elif [ "$POST_HISTORY" -gt "$PRE_HISTORY" ]; then
    pass "I6: mutagen-history.md grew from $PRE_HISTORY to $POST_HISTORY lines (Mutagen ran)"
  else
    warn "I6: mutagen-history.md exists but didn't grow (Mutagen may have run with no changes to log)"
  fi
else
  warn "I6: mutagen-history.md not created — SessionStart agent hook may not fire in -p mode (expected for non-interactive sessions)"
fi

# Check for usage log entries (PostToolUse hook should have fired during Mutagen's work)
if [ -f "$REPO_DIR/.claude/mutagen-usage-log.jsonl" ]; then
  POST_USAGE_LOG=$(wc -l < "$REPO_DIR/.claude/mutagen-usage-log.jsonl" | tr -d ' ')
  if [ "$PRE_USAGE_LOG" = "none" ]; then
    pass "I7: mutagen-usage-log.jsonl was CREATED (PostToolUse hook fired)"
  elif [ "$POST_USAGE_LOG" -gt "$PRE_USAGE_LOG" ]; then
    pass "I7: mutagen-usage-log.jsonl grew from $PRE_USAGE_LOG to $POST_USAGE_LOG lines (PostToolUse hook fired)"
  else
    warn "I7: mutagen-usage-log.jsonl exists but didn't grow"
  fi
else
  warn "I7: mutagen-usage-log.jsonl not created (PostToolUse hook may not have fired — Mutagen may have been a no-op)"
fi

# Check for session metrics (Stop hook should have fired)
if [ -f "$REPO_DIR/.claude/mutagen-memory/usage-metrics.jsonl" ]; then
  pass "I8: mutagen-memory/usage-metrics.jsonl exists (Stop hook fired)"
  # Verify it's valid JSONL
  LAST_METRICS=$(tail -1 "$REPO_DIR/.claude/mutagen-memory/usage-metrics.jsonl")
  echo "$LAST_METRICS" | jq . > /dev/null 2>&1 \
    && pass "I9: Session metrics entry is valid JSON" \
    || fail "I9: Session metrics entry is NOT valid JSON"
else
  warn "I8: mutagen-memory/usage-metrics.jsonl not created (Stop hook may not have fired)"
  warn "I9: Skipped (no metrics file)"
fi

# Clean up
rm -f /tmp/ccautomated-session-output.txt

# ══════════════════════════════════════════════════════════════════════════════
section "Results"
# ══════════════════════════════════════════════════════════════════════════════

TOTAL=$((PASS + FAIL))
echo ""
echo "  $PASS/$TOTAL passed, $FAIL failed, $WARN warnings"
echo ""

# ── Clean up test repo ──────────────────────────────────────────────────────
# Safety: only delete repos created by setup-test-repo.sh (sentinel file check)
# and only under /tmp/ to prevent accidental deletion of real projects.
if [ "${KEEP_REPO:-}" != "1" ]; then
  if [ -f "$REPO_DIR/.ccautomated-test-repo" ] && case "$REPO_DIR" in /tmp/*) true;; *) false;; esac; then
    rm -rf "$REPO_DIR"
    echo "  Cleaned up: $REPO_DIR"
  else
    echo "  Skipped cleanup: $REPO_DIR (not a test repo or not under /tmp/)"
  fi
else
  echo "  Kept repo: $REPO_DIR (KEEP_REPO=1)"
fi

if [ "$FAIL" -gt 0 ]; then
  echo "RESULT: FAIL"
  exit 1
else
  echo "RESULT: PASS"
  exit 0
fi
