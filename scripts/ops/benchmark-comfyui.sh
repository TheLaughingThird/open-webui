#!/usr/bin/env bash
set -euo pipefail

# Benchmarks ComfyUI by submitting a workflow and measuring total completion time.
# Uses the same workflow file repeatedly for CPU vs GPU comparisons.

COMFYUI_URL="${COMFYUI_URL:-http://localhost:8188}"
WORKFLOW_FILE="${WORKFLOW_FILE:-}"
RUNS="${RUNS:-3}"
MODE_LABEL="${MODE_LABEL:-cpu}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-1}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"
OUTFILE="${OUTFILE:-}"

if [ -z "$WORKFLOW_FILE" ] || [ ! -f "$WORKFLOW_FILE" ]; then
	echo "Set WORKFLOW_FILE to a valid ComfyUI API workflow JSON file" >&2
	exit 1
fi

if ! [[ "$RUNS" =~ ^[0-9]+$ ]] || [ "$RUNS" -lt 1 ]; then
	echo "RUNS must be a positive integer" >&2
	exit 1
fi

timestamp_utc() {
	date -u +"%Y-%m-%dT%H:%M:%SZ"
}

append_csv() {
	local line="$1"
	if [ -n "$OUTFILE" ]; then
		mkdir -p "$(dirname "$OUTFILE")"
		if [ ! -f "$OUTFILE" ]; then
			echo "timestamp,mode,run,workflow_file,total_seconds,status" >>"$OUTFILE"
		fi
		echo "$line" >>"$OUTFILE"
	fi
}

extract_prompt_id() {
	sed -n 's/.*"prompt_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

echo "Benchmarking ComfyUI at $COMFYUI_URL workflow=$WORKFLOW_FILE runs=$RUNS mode=$MODE_LABEL"

for run in $(seq 1 "$RUNS"); do
	start_epoch="$(date +%s)"
	submit_payload=$(printf '{"prompt":%s}' "$(cat "$WORKFLOW_FILE")")

	submit_response="$(
		curl -sS \
			-H 'Content-Type: application/json' \
			-d "$submit_payload" \
			"$COMFYUI_URL/prompt"
	)"

	prompt_id="$(printf '%s' "$submit_response" | extract_prompt_id)"
	if [ -z "$prompt_id" ]; then
		echo "Could not parse prompt_id from ComfyUI response:" >&2
		echo "$submit_response" >&2
		exit 1
	fi

	status="ok"
	while true; do
		now_epoch="$(date +%s)"
		elapsed=$((now_epoch - start_epoch))
		if [ "$elapsed" -ge "$TIMEOUT_SECONDS" ]; then
			status="timeout"
			break
		fi

		history_response="$(curl -sS "$COMFYUI_URL/history/$prompt_id")"
		if printf '%s' "$history_response" | grep -q "\"$prompt_id\""; then
			break
		fi

		sleep "$POLL_INTERVAL_SECONDS"
	done

	end_epoch="$(date +%s)"
	total_seconds=$((end_epoch - start_epoch))
	ts="$(timestamp_utc)"
	line="$ts,$MODE_LABEL,$run,$WORKFLOW_FILE,$total_seconds,$status"
	echo "$line"
	append_csv "$line"

	if [ "$status" != "ok" ]; then
		exit 1
	fi
done

