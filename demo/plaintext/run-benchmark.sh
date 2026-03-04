#!/bin/bash
# =============================================================================
# Run TFB plaintext-style wrk bench for a given server
# =============================================================================
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <label> <port> <command...>"
  exit 1
fi

LABEL="$1"
PORT="$2"
shift 2
CMD=("$@")
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/artifacts"
mkdir -p "$LOG_DIR"
RESULT_FILE="$LOG_DIR/${LABEL}-wrk.csv"
SERVER_LOG="$LOG_DIR/${LABEL}-server.log"
WRK_CMD="${WRK_CMD:-wrk}"

if ! command -v "$WRK_CMD" >/dev/null 2>&1; then
  echo "wrk not found: tried '$WRK_CMD'. Install wrk or set WRK_CMD to the binary path." >&2
  exit 1
fi

echo "label,concurrency,requests_per_sec,latency_avg" > "$RESULT_FILE"

TFB_URL="http://127.0.0.1:${PORT}/plaintext"

start_server() {
  TFB_PORT="$PORT" PORT="$PORT" "${CMD[@]}" >"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!
  trap 'kill $SERVER_PID 2>/dev/null || true' EXIT
  sleep 1
}

stop_server() {
  kill $SERVER_PID 2>/dev/null || true
  wait $SERVER_PID 2>/dev/null || true
  trap - EXIT
}

run_wrk() {
  local concurrency=$1
  local output_file="$LOG_DIR/${LABEL}-c${concurrency}.txt"
  "$WRK_CMD" -t4 -c${concurrency} -d15s "$TFB_URL" >"$output_file"
  local rps
  local latency
  rps=$(awk '/Requests\/sec/ {print $2}' "$output_file" | tail -n1)
  latency=$(awk '/Latency/ {print $2}' "$output_file" | head -n1)
  printf "%s,%s,%s,%s\n" "$LABEL" "$concurrency" "$rps" "$latency" >> "$RESULT_FILE"
}

start_server
for conc in 256 1024 4096 16384; do
  echo "[benchmark] $LABEL concurrency=$conc"
  run_wrk "$conc"
done
stop_server
