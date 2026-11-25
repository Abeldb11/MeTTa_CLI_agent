#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export AGENT_WORKDIR="${AGENT_WORKDIR:-$SCRIPT_DIR/workspace}"
export AGENT_LLM_URL="${AGENT_LLM_URL:-http://localhost:11434}"
export AGENT_MODEL="${AGENT_MODEL:-qwen2.5:7b-instruct}"
export AGENT_TRACE="${AGENT_TRACE:-0}"
export AGENT_MOCK="${AGENT_MOCK:-0}"
export PETTA_HOME="${PETTA_HOME:-$HOME/PeTTa}"

mkdir -p "$AGENT_WORKDIR" "$SCRIPT_DIR/logs"

# Parse optional --trace and --mock flags
for arg in "$@"; do
  case "$arg" in
    --trace) export AGENT_TRACE=1 ;;
    --mock)  export AGENT_MOCK=1 ;;
  esac
done

if [ ! -f "$PETTA_HOME/run.sh" ]; then
  echo "ERROR: PeTTa not found at PETTA_HOME=$PETTA_HOME"
  echo "Set PETTA_HOME to your PeTTa installation directory."
  exit 1
fi

(cd "$PETTA_HOME" && sh run.sh "$SCRIPT_DIR/agent.metta")