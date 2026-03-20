#!/usr/bin/env bash
# validate-setup.sh — Validates a generated Claude Code setup for completeness,
# correctness, and Mutagen tracking pipeline integrity.
#
# Usage: ./tests/validate-setup.sh [/path/to/target-repo]
#        Defaults to /tmp/ccautomated-test-repo if no argument given.
#        Set KEEP_REPO=1 to preserve the test repo after the run.
set -uo pipefail

REPO_DIR="${1:-/tmp/ccautomated-test-repo}"
PASS=0
FAIL=0
WARN=0

# ── Helpers ───────────────────────────────────────────────────────────────────
pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

section() { echo ""; echo "=== $1 ==="; }

# ── Pre-flight ────────────────────────────────────────────────────────────────
if [ ! -d "$REPO_DIR" ]; then
  echo "ERROR: $REPO_DIR does not exist"
  exit 1
fi

cd "$REPO_DIR" || { echo "ERROR: Could not cd to $REPO_DIR"; exit 1; }
echo "Validating setup at: $REPO_DIR"

# ══════════════════════════════════════════════════════════════════════════════
section "S: Structural Checks"
# ══════════════════════════════════════════════════════════════════════════════

# S1: .claude/ directory
[ -d ".claude" ] && pass "S1: .claude/ directory exists" || fail "S1: .claude/ directory missing"

# S2: CLAUDE.md exists and non-empty
[ -s "CLAUDE.md" ] && pass "S2: CLAUDE.md exists and is non-empty" || fail "S2: CLAUDE.md missing or empty"

# S3: settings.json valid JSON
if [ -f ".claude/settings.json" ]; then
  jq . ".claude/settings.json" > /dev/null 2>&1 \
    && pass "S3: settings.json is valid JSON" \
    || fail "S3: settings.json is NOT valid JSON"
else
  fail "S3: .claude/settings.json missing"
fi

# S4: .mcp.json valid JSON (if present)
if [ -f ".mcp.json" ]; then
  jq . ".mcp.json" > /dev/null 2>&1 \
    && pass "S4: .mcp.json is valid JSON" \
    || fail "S4: .mcp.json is NOT valid JSON"
else
  warn "S4: .mcp.json not present (may be intentional)"
fi

# S5-S6: .gitignore includes .claude/ and CLAUDE.md
if [ -f ".gitignore" ]; then
  grep -q '\.claude' ".gitignore" \
    && pass "S5: .gitignore includes .claude/" \
    || fail "S5: .gitignore missing .claude/"
  grep -q 'CLAUDE\.md' ".gitignore" \
    && pass "S6: .gitignore includes CLAUDE.md" \
    || fail "S6: .gitignore missing CLAUDE.md"
else
  fail "S5: .gitignore missing"
  fail "S6: .gitignore missing"
fi

# ══════════════════════════════════════════════════════════════════════════════
section "M: Mutagen Tracking Pipeline"
# ══════════════════════════════════════════════════════════════════════════════

# M1-M2: post-tool-use.sh exists and is executable
if [ -f ".claude/hooks/post-tool-use.sh" ]; then
  pass "M1: post-tool-use.sh exists"
  [ -x ".claude/hooks/post-tool-use.sh" ] \
    && pass "M2: post-tool-use.sh is executable" \
    || fail "M2: post-tool-use.sh is NOT executable"
else
  fail "M1: .claude/hooks/post-tool-use.sh missing"
  fail "M2: post-tool-use.sh not found (can't check executable)"
fi

# M3-M4: stop-session-metrics.sh exists and is executable
if [ -f ".claude/hooks/stop-session-metrics.sh" ]; then
  pass "M3: stop-session-metrics.sh exists"
  [ -x ".claude/hooks/stop-session-metrics.sh" ] \
    && pass "M4: stop-session-metrics.sh is executable" \
    || fail "M4: stop-session-metrics.sh is NOT executable"
else
  fail "M3: .claude/hooks/stop-session-metrics.sh missing"
  fail "M4: stop-session-metrics.sh not found (can't check executable)"
fi

# M5: post-tool-use.sh uses jq (not template variables)
if [ -f ".claude/hooks/post-tool-use.sh" ]; then
  grep -q 'jq' ".claude/hooks/post-tool-use.sh" \
    && pass "M5a: post-tool-use.sh uses jq for stdin parsing" \
    || fail "M5a: post-tool-use.sh does NOT use jq"
  ! grep -q '{{toolName}}' ".claude/hooks/post-tool-use.sh" \
    && pass "M5b: post-tool-use.sh has no broken {{toolName}} template vars" \
    || fail "M5b: post-tool-use.sh still contains {{toolName}} template variables"
fi

# M6: post-tool-use.sh classifies all 5 event types
if [ -f ".claude/hooks/post-tool-use.sh" ]; then
  ALL_TYPES=true
  for TYPE in builtin skill mcp bash agent; do
    if grep -q "type.*$TYPE" ".claude/hooks/post-tool-use.sh"; then
      : # found
    else
      ALL_TYPES=false
      fail "M6: post-tool-use.sh missing classification for type: $TYPE"
    fi
  done
  $ALL_TYPES && pass "M6: post-tool-use.sh classifies all 5 event types (builtin, skill, mcp, bash, agent)"
fi

# M7: stop-session-metrics.sh captures user slash commands
if [ -f ".claude/hooks/stop-session-metrics.sh" ]; then
  grep -q 'startswith("/")' ".claude/hooks/stop-session-metrics.sh" \
    && pass "M7: stop-session-metrics.sh captures user slash commands" \
    || fail "M7: stop-session-metrics.sh does NOT capture user slash commands"
fi

# M8: stop-session-metrics.sh deduplicates by session_id
if [ -f ".claude/hooks/stop-session-metrics.sh" ]; then
  grep -q 'session_id' ".claude/hooks/stop-session-metrics.sh" \
    && grep -q 'tmp' ".claude/hooks/stop-session-metrics.sh" \
    && pass "M8: stop-session-metrics.sh deduplicates by session_id" \
    || fail "M8: stop-session-metrics.sh missing deduplication logic"
fi

# M9-M11: settings.json hook references
if [ -f ".claude/settings.json" ]; then
  jq -e '.hooks.PostToolUse[0].hooks[0].command' ".claude/settings.json" 2>/dev/null | grep -q 'post-tool-use' \
    && pass "M9: settings.json PostToolUse hook references post-tool-use.sh" \
    || fail "M9: settings.json PostToolUse hook missing or wrong path"

  jq -e '.hooks.Stop[0].hooks[0].command' ".claude/settings.json" 2>/dev/null | grep -q 'stop-session-metrics' \
    && pass "M10: settings.json Stop hook references stop-session-metrics.sh" \
    || fail "M10: settings.json Stop hook missing or wrong path"

  jq -e '.hooks.SessionStart[0].hooks[0].agent' ".claude/settings.json" 2>/dev/null | grep -q 'mutagen' \
    && pass "M11: settings.json SessionStart hook triggers mutagen agent" \
    || fail "M11: settings.json SessionStart hook missing or wrong agent"
fi

# M12-M13: Mutagen agents exist
[ -f ".claude/agents/mutagen.md" ] \
  && pass "M12: mutagen.md agent exists" \
  || fail "M12: .claude/agents/mutagen.md missing"

[ -f ".claude/agents/mutagen-discovery.md" ] \
  && pass "M13: mutagen-discovery.md agent exists" \
  || fail "M13: .claude/agents/mutagen-discovery.md missing"

# M14-M16: Mutagen agent references correct log files and user_commands
if [ -f ".claude/agents/mutagen.md" ]; then
  grep -q 'mutagen-usage-log.jsonl' ".claude/agents/mutagen.md" \
    && pass "M14: mutagen.md references mutagen-usage-log.jsonl" \
    || fail "M14: mutagen.md does NOT reference mutagen-usage-log.jsonl"

  grep -q 'usage-metrics.jsonl' ".claude/agents/mutagen.md" \
    && pass "M15: mutagen.md references usage-metrics.jsonl" \
    || fail "M15: mutagen.md does NOT reference usage-metrics.jsonl"

  grep -q 'user_commands\|user.command\|slash.command\|user.*command' ".claude/agents/mutagen.md" \
    && pass "M16: mutagen.md references user command tracking" \
    || fail "M16: mutagen.md does NOT reference user command tracking"
fi

# M17-M18: Mutagen memory directory initialized
[ -f ".claude/mutagen-memory/plugin-registry.md" ] \
  && pass "M17: mutagen-memory/plugin-registry.md exists" \
  || fail "M17: .claude/mutagen-memory/plugin-registry.md missing"

[ -f ".claude/mutagen-memory/improvement-log.md" ] \
  && pass "M18: mutagen-memory/improvement-log.md exists" \
  || fail "M18: .claude/mutagen-memory/improvement-log.md missing"

# ══════════════════════════════════════════════════════════════════════════════
section "A: Agent Quality"
# ══════════════════════════════════════════════════════════════════════════════

# A1: All agents have model: opus
if [ -d ".claude/agents" ]; then
  ALL_OPUS=true
  for agent in .claude/agents/*.md; do
    [ -f "$agent" ] || continue
    AGENT_NAME=$(basename "$agent")
    if grep -q 'model:.*opus' "$agent"; then
      : # good
    else
      ALL_OPUS=false
      fail "A1: $AGENT_NAME does NOT have model: opus"
    fi
  done
  $ALL_OPUS && pass "A1: All agents have model: opus"
else
  fail "A1: .claude/agents/ directory missing"
fi

# A2: Mutagen has Agent in tools
if [ -f ".claude/agents/mutagen.md" ]; then
  grep -q 'tools:.*Agent' ".claude/agents/mutagen.md" \
    && pass "A2: mutagen.md has Agent in tools (can spawn discovery)" \
    || fail "A2: mutagen.md missing Agent in tools"
fi

# A3: No agent has bypassPermissions
if [ -d ".claude/agents" ]; then
  ! grep -rl 'bypassPermissions' .claude/agents/ > /dev/null 2>&1 \
    && pass "A3: No agent uses bypassPermissions" \
    || fail "A3: An agent uses bypassPermissions"
fi

# ══════════════════════════════════════════════════════════════════════════════
section "F: Functional Smoke Tests"
# ══════════════════════════════════════════════════════════════════════════════

# F1: post-tool-use.sh accepts mock JSON and produces valid JSONL
if [ -x ".claude/hooks/post-tool-use.sh" ]; then
  # Clean up any previous test output
  rm -f ".claude/mutagen-usage-log.jsonl"

  echo '{"tool_name":"Read","tool_input":{"file_path":"/tmp/test"},"session_id":"test-123","hook_event_name":"PostToolUse"}' \
    | .claude/hooks/post-tool-use.sh 2>/dev/null

  if [ -f ".claude/mutagen-usage-log.jsonl" ]; then
    LAST_LINE=$(tail -1 ".claude/mutagen-usage-log.jsonl")
    echo "$LAST_LINE" | jq . > /dev/null 2>&1 \
      && pass "F1: post-tool-use.sh produces valid JSONL output" \
      || fail "F1: post-tool-use.sh output is NOT valid JSON: $LAST_LINE"
  else
    fail "F1: post-tool-use.sh did not create usage log file"
  fi
else
  warn "F1: post-tool-use.sh not executable, skipping smoke test"
fi

# F2: Skill event classification
if [ -x ".claude/hooks/post-tool-use.sh" ]; then
  echo '{"tool_name":"Skill","tool_input":{"skill":"test","args":"--watch"},"session_id":"test-123","hook_event_name":"PostToolUse"}' \
    | .claude/hooks/post-tool-use.sh 2>/dev/null

  LAST_LINE=$(tail -1 ".claude/mutagen-usage-log.jsonl")
  echo "$LAST_LINE" | jq -e 'select(.type == "skill" and .name == "test")' > /dev/null 2>&1 \
    && pass "F2: Skill event correctly classified (type=skill, name=test)" \
    || fail "F2: Skill event NOT correctly classified: $LAST_LINE"
fi

# F3: MCP event classification
if [ -x ".claude/hooks/post-tool-use.sh" ]; then
  echo '{"tool_name":"mcp__context7__resolve-library-id","tool_input":{},"session_id":"test-123","hook_event_name":"PostToolUse"}' \
    | .claude/hooks/post-tool-use.sh 2>/dev/null

  LAST_LINE=$(tail -1 ".claude/mutagen-usage-log.jsonl")
  echo "$LAST_LINE" | jq -e 'select(.type == "mcp" and .server == "context7")' > /dev/null 2>&1 \
    && pass "F3: MCP event correctly classified (type=mcp, server=context7)" \
    || fail "F3: MCP event NOT correctly classified: $LAST_LINE"
fi

# F4: stop-session-metrics.sh exits cleanly with stop_hook_active
if [ -x ".claude/hooks/stop-session-metrics.sh" ]; then
  echo '{"stop_hook_active":true,"session_id":"test-123","hook_event_name":"Stop"}' \
    | .claude/hooks/stop-session-metrics.sh 2>/dev/null
  [ $? -eq 0 ] \
    && pass "F4: stop-session-metrics.sh exits cleanly when stop_hook_active=true" \
    || fail "F4: stop-session-metrics.sh did NOT exit cleanly with stop_hook_active=true"
fi

# F5: Bash event classification
if [ -x ".claude/hooks/post-tool-use.sh" ]; then
  echo '{"tool_name":"Bash","tool_input":{"command":"npm test"},"session_id":"test-123","hook_event_name":"PostToolUse"}' \
    | .claude/hooks/post-tool-use.sh 2>/dev/null

  LAST_LINE=$(tail -1 ".claude/mutagen-usage-log.jsonl")
  echo "$LAST_LINE" | jq -e 'select(.type == "bash" and .name == "npm")' > /dev/null 2>&1 \
    && pass "F5: Bash event correctly classified (type=bash, name=npm)" \
    || fail "F5: Bash event NOT correctly classified: $LAST_LINE"
fi

# F6: Agent event classification
if [ -x ".claude/hooks/post-tool-use.sh" ]; then
  echo '{"tool_name":"Agent","tool_input":{"subagent_type":"code-researcher","description":"Analyze repo"},"session_id":"test-123","hook_event_name":"PostToolUse"}' \
    | .claude/hooks/post-tool-use.sh 2>/dev/null

  LAST_LINE=$(tail -1 ".claude/mutagen-usage-log.jsonl")
  echo "$LAST_LINE" | jq -e 'select(.type == "agent" and .name == "code-researcher")' > /dev/null 2>&1 \
    && pass "F6: Agent event correctly classified (type=agent, name=code-researcher)" \
    || fail "F6: Agent event NOT correctly classified: $LAST_LINE"
fi

# F7: Subagent attribution — agent_type field is captured correctly
if [ -x ".claude/hooks/post-tool-use.sh" ]; then
  echo '{"tool_name":"Skill","tool_input":{"skill":"review-config"},"session_id":"test-123","hook_event_name":"PostToolUse","agent_type":"reviewer","agent_id":"agent-abc123"}' \
    | .claude/hooks/post-tool-use.sh 2>/dev/null

  LAST_LINE=$(tail -1 ".claude/mutagen-usage-log.jsonl")
  echo "$LAST_LINE" | jq -e 'select(.type == "skill" and .name == "review-config" and .agent == "reviewer")' > /dev/null 2>&1 \
    && pass "F7: Subagent attribution works (agent=reviewer, not main)" \
    || fail "F7: Subagent attribution failed — expected agent=reviewer: $LAST_LINE"
fi

# F8: Main thread defaults to agent=main when no agent_type
if [ -x ".claude/hooks/post-tool-use.sh" ]; then
  echo '{"tool_name":"Read","tool_input":{"file_path":"/test"},"session_id":"test-123","hook_event_name":"PostToolUse"}' \
    | .claude/hooks/post-tool-use.sh 2>/dev/null

  LAST_LINE=$(tail -1 ".claude/mutagen-usage-log.jsonl")
  echo "$LAST_LINE" | jq -e 'select(.agent == "main")' > /dev/null 2>&1 \
    && pass "F8: Main thread defaults to agent=main when no agent_type" \
    || fail "F8: Main thread agent field wrong — expected main: $LAST_LINE"
fi

# Clean up smoke test artifacts
rm -f ".claude/mutagen-usage-log.jsonl"

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
