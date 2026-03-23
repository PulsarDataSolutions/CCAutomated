#!/usr/bin/env bash
# stop-metrics.sh — Collects session usage metrics for Mutagen analysis
# Called by the Stop hook. Reads transcript JSONL, aggregates tool/agent/skill
# usage, writes a structured entry to .claude/mutagen-memory/usage-metrics.jsonl,
# and sends a macOS notification with a summary.

set -uo pipefail

# ── Read hook input from stdin ────────────────────────────────────────────────
INPUT=$(cat)

# ── Guard: prevent infinite loops ─────────────────────────────────────────────
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# ── Extract fields ────────────────────────────────────────────────────────────
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_RAW=$(echo "$INPUT" | jq -r '.transcript_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Expand tilde in transcript path
TRANSCRIPT="${TRANSCRIPT_RAW/#\~/$HOME}"

# ── Validate: bail if we don't have what we need ─────────────────────────────
if [ -z "$SESSION_ID" ] || [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  # Nothing to do — fire the notification anyway and exit cleanly
  osascript -e 'display notification "Session ended (no metrics collected)" with title "CCAutomated"' 2>/dev/null || true
  exit 0
fi

# ── Resolve paths ─────────────────────────────────────────────────────────────
# CCAutomated repo root — the hook always runs from CCAutomated's context
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
METRICS_FILE="$REPO_ROOT/.claude/mutagen-memory/usage-metrics.jsonl"
TRANSCRIPT_DIR="$(dirname "$TRANSCRIPT")"
SUBAGENTS_DIR="$TRANSCRIPT_DIR/$SESSION_ID/subagents"

# Ensure metrics directory exists
mkdir -p "$(dirname "$METRICS_FILE")"

# ── Helper: build JSON object from "count name" lines ────────────────────────
# Reads stdin of "  N name" lines (uniq -c output), outputs {"name":N,...}
# Returns "{}" for empty input. Safe under pipefail.
count_to_json() {
  local input
  input=$(cat)
  if [ -z "$input" ]; then
    echo "{}"
    return 0
  fi
  echo "$input" | awk '{
    gsub(/"/, "", $2)
    if (seen++) printf ","
    printf "\"%s\":%s", $2, $1
  } BEGIN { printf "{" } END { printf "}" }'
}

# ── Helper: extract tool names from a JSONL transcript ────────────────────────
extract_tool_names() {
  local file="$1"
  jq -c '
    select(.type == "assistant")
    | .message.content[]?
    | select(.type == "tool_use")
    | .name
  ' "$file" 2>/dev/null || true
}

# ── Parse main transcript for tool usage ──────────────────────────────────────
MAIN_TOOL_NAMES=$(extract_tool_names "$TRANSCRIPT")

TOOL_COUNTS=""
if [ -n "$MAIN_TOOL_NAMES" ]; then
  TOOL_COUNTS=$(echo "$MAIN_TOOL_NAMES" | sort | uniq -c | sort -rn \
    | awk '{printf "%s:%s\n", $2, $1}' | tr -d '"')
fi

TOOLS_JSON="{}"
if [ -n "$TOOL_COUNTS" ]; then
  TOOLS_JSON=$(echo "$TOOL_COUNTS" | awk -F: '
    BEGIN { printf "{" }
    NF==2 && $1!="" {
      if (seen++) printf ","
      gsub(/^ +| +$/, "", $1)
      printf "\"%s\":%s", $1, $2
    }
    END { printf "}" }
  ')
fi
[ -z "$TOOLS_JSON" ] && TOOLS_JSON="{}"

TOTAL_CALLS=0
if [ -n "$TOOL_COUNTS" ]; then
  TOTAL_CALLS=$(echo "$TOOL_COUNTS" | awk -F: '{s+=$2} END {print s+0}')
fi

UNIQUE_TOOLS=0
if [ -n "$TOOL_COUNTS" ]; then
  UNIQUE_TOOLS=$(echo "$TOOL_COUNTS" | grep -c . 2>/dev/null) || UNIQUE_TOOLS=0
fi

# ── Extract Agent spawns with subagent types ──────────────────────────────────
AGENTS_RAW=$(jq -c '
  select(.type == "assistant")
  | .message.content[]?
  | select(.type == "tool_use" and .name == "Agent")
  | .input.subagent_type // .input.description // "unknown"
' "$TRANSCRIPT" 2>/dev/null || true)

AGENTS_JSON="{}"
if [ -n "$AGENTS_RAW" ]; then
  AGENTS_JSON=$(echo "$AGENTS_RAW" | sort | uniq -c | sort -rn | count_to_json)
fi

# ── Extract Skill invocations ─────────────────────────────────────────────────
SKILLS_RAW=$(jq -c '
  select(.type == "assistant")
  | .message.content[]?
  | select(.type == "tool_use" and .name == "Skill")
  | .input.skill // "unknown"
' "$TRANSCRIPT" 2>/dev/null || true)

SKILLS_JSON="[]"
if [ -n "$SKILLS_RAW" ]; then
  SKILLS_JSON=$(echo "$SKILLS_RAW" | sort -u | jq -R -s 'split("\n") | map(select(. != ""))' 2>/dev/null || echo "[]")
fi

# ── Extract MCP tool usage (namespaced tools: mcp__server__tool) ──────────────
MCP_RAW=$(jq -c '
  select(.type == "assistant")
  | .message.content[]?
  | select(.type == "tool_use" and (.name | test("^mcp__")))
  | .name
' "$TRANSCRIPT" 2>/dev/null || true)

MCP_JSON="{}"
if [ -n "$MCP_RAW" ]; then
  MCP_JSON=$(echo "$MCP_RAW" | sort | uniq -c | sort -rn | count_to_json)
fi

# ── Extract top Bash commands (base command only) ─────────────────────────────
BASH_RAW=$(jq -c '
  select(.type == "assistant")
  | .message.content[]?
  | select(.type == "tool_use" and .name == "Bash")
  | .input.command
  | split(" ") | .[0]
  | gsub("\""; "")
' "$TRANSCRIPT" 2>/dev/null || true)

BASH_CMDS_JSON="{}"
if [ -n "$BASH_RAW" ]; then
  BASH_CMDS_JSON=$(echo "$BASH_RAW" | sort | uniq -c | sort -rn | head -10 | count_to_json)
fi

# ── Scan subagent transcripts (with per-agent tool breakdown) ─────────────────
SUBAGENT_DETAILS="[]"
ALL_SUBAGENT_TOOLS=""
if [ -d "$SUBAGENTS_DIR" ]; then
  SUBAGENT_DETAILS=$(
    for meta in "$SUBAGENTS_DIR"/*.meta.json; do
      [ -f "$meta" ] || continue
      AGENT_TYPE=$(jq -r '.agentType // "unknown"' "$meta" 2>/dev/null)
      DESCRIPTION=$(jq -r '.description // ""' "$meta" 2>/dev/null)

      AGENT_JSONL="${meta%.meta.json}.jsonl"
      AGENT_TOOLS_OBJ="{}"
      AGENT_TOOL_COUNT=0
      if [ -f "$AGENT_JSONL" ]; then
        AGENT_TOOL_NAMES=$(extract_tool_names "$AGENT_JSONL")

        if [ -n "$AGENT_TOOL_NAMES" ]; then
          AGENT_TOOLS_OBJ=$(echo "$AGENT_TOOL_NAMES" | sort | uniq -c | sort -rn | count_to_json)
          AGENT_TOOL_COUNT=$(echo "$AGENT_TOOL_NAMES" | wc -l | tr -d ' ')
        fi
      fi

      jq -nc --arg type "$AGENT_TYPE" --arg desc "$DESCRIPTION" \
        --argjson tools "$AGENT_TOOLS_OBJ" --argjson total "$AGENT_TOOL_COUNT" \
        '{"type": $type, "description": $desc, "tools": $tools, "tool_calls": $total}'
    done | jq -sc '.' 2>/dev/null || echo "[]"
  )

  # Collect all subagent tool names for the combined total
  for jsonl in "$SUBAGENTS_DIR"/*.jsonl; do
    [ -f "$jsonl" ] || continue
    NAMES=$(extract_tool_names "$jsonl")
    if [ -n "$NAMES" ]; then
      ALL_SUBAGENT_TOOLS="${ALL_SUBAGENT_TOOLS}
${NAMES}"
    fi
  done
fi

# ── Build combined tool counts (main thread + all subagents) ──────────────────
ALL_TOOL_NAMES="$MAIN_TOOL_NAMES"
if [ -n "$ALL_SUBAGENT_TOOLS" ]; then
  ALL_TOOL_NAMES="${ALL_TOOL_NAMES}
${ALL_SUBAGENT_TOOLS}"
fi

COMBINED_JSON="{}"
COMBINED_TOTAL=0
FILTERED_NAMES=$(echo "$ALL_TOOL_NAMES" | grep -v '^$' || true)
if [ -n "$FILTERED_NAMES" ]; then
  COMBINED_JSON=$(echo "$FILTERED_NAMES" | sort | uniq -c | sort -rn | count_to_json)
  COMBINED_TOTAL=$(echo "$FILTERED_NAMES" | wc -l | tr -d ' ')
fi

# ── Calculate session duration ────────────────────────────────────────────────
DURATION_SECONDS="null"
# Session metadata is keyed by PID at ~/.claude/sessions/{pid}.json
# Search for our session_id across session files
SESSIONS_DIR="$HOME/.claude/sessions"
if [ -d "$SESSIONS_DIR" ]; then
  for sf in "$SESSIONS_DIR"/*.json; do
    [ -f "$sf" ] || continue
    SF_SESSION_ID=$(jq -r '.sessionId // empty' "$sf" 2>/dev/null)
    if [ "$SF_SESSION_ID" = "$SESSION_ID" ]; then
      STARTED_AT=$(jq -r '.startedAt // empty' "$sf" 2>/dev/null)
      if [ -n "$STARTED_AT" ]; then
        NOW_S=$(date +%s)
        DURATION_SECONDS=$(( NOW_S - ${STARTED_AT%???} ))
        [ "$DURATION_SECONDS" -lt 0 ] && DURATION_SECONDS="null"
      fi
      break
    fi
  done
fi

# ── Format duration for notification ──────────────────────────────────────────
if [ "$DURATION_SECONDS" != "null" ] && [ "$DURATION_SECONDS" -gt 0 ]; then
  MINS=$((DURATION_SECONDS / 60))
  SECS=$((DURATION_SECONDS % 60))
  if [ "$MINS" -gt 0 ]; then
    DURATION_DISPLAY="${MINS}m${SECS}s"
  else
    DURATION_DISPLAY="${SECS}s"
  fi
else
  DURATION_DISPLAY="unknown"
fi

# ── Build final metrics JSON ──────────────────────────────────────────────────
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

METRICS=$(jq -nc \
  --arg sid "$SESSION_ID" \
  --arg project "$CWD" \
  --arg ts "$TIMESTAMP" \
  --argjson duration "$DURATION_SECONDS" \
  --argjson main_tools "$TOOLS_JSON" \
  --argjson combined_tools "$COMBINED_JSON" \
  --argjson combined_total "$COMBINED_TOTAL" \
  --argjson skills "$SKILLS_JSON" \
  --argjson agents "$AGENTS_JSON" \
  --argjson mcp "$MCP_JSON" \
  --argjson bash_cmds "$BASH_CMDS_JSON" \
  --argjson subagents "$SUBAGENT_DETAILS" \
  --argjson main_total "$TOTAL_CALLS" \
  --argjson main_unique "$UNIQUE_TOOLS" \
  '{
    session_id: $sid,
    project: $project,
    timestamp: $ts,
    duration_seconds: $duration,
    tools_main_thread: $main_tools,
    tools_combined: $combined_tools,
    skills_invoked: $skills,
    agents_spawned: $agents,
    mcp_tools: $mcp,
    bash_commands: $bash_cmds,
    subagent_details: $subagents,
    total_tool_calls_main: $main_total,
    total_tool_calls_combined: $combined_total,
    unique_tools_main: $main_unique
  }')

# ── Write metrics entry (deduplicate by session_id) ──────────────────────────
# Remove any existing entry for this session, then append the updated one.
# This way each session only has one entry — the latest snapshot.
if [ -f "$METRICS_FILE" ]; then
  TMP_FILE="${METRICS_FILE}.tmp.$$"
  jq -c "select(.session_id != \"$SESSION_ID\")" "$METRICS_FILE" > "$TMP_FILE" 2>/dev/null || true
  mv "$TMP_FILE" "$METRICS_FILE"
fi
echo "$METRICS" >> "$METRICS_FILE"

# ── Send macOS notification with summary ──────────────────────────────────────
AGENT_COUNT=$(echo "$AGENTS_JSON" | jq 'to_entries | map(.value) | add // 0' 2>/dev/null || echo 0)
DIR_NAME=$(basename "$CWD")
NOTIF_MSG="${COMBINED_TOTAL} tools used, ${AGENT_COUNT} agents spawned — ${DURATION_DISPLAY}"
osascript -e "display notification \"$NOTIF_MSG\" with title \"$DIR_NAME\" sound name \"Glass\"" 2>/dev/null || true

exit 0
