#!/usr/bin/env bash
set -euo pipefail

# Simple repeatable benchmark for Ollama API total response time.
# Compare CPU vs GPU by changing compose mode, not this script.

OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2:3b}"
PROMPT="${PROMPT:-Write one short sentence about benchmarking.}"
RUNS="${RUNS:-3}"
MODE_LABEL="${MODE_LABEL:-cpu}"
OUTFILE="${OUTFILE:-}"

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
			echo "timestamp,mode,run,model,total_seconds,http_code" >>"$OUTFILE"
		fi
		echo "$line" >>"$OUTFILE"
	fi
}

echo "Benchmarking Ollama at $OLLAMA_URL with model=$OLLAMA_MODEL runs=$RUNS mode=$MODE_LABEL"

for run in $(seq 1 "$RUNS"); do
	tmp_body="$(mktemp)"
	payload=$(printf '{"model":"%s","prompt":"%s","stream":false}' \
		"$OLLAMA_MODEL" \
		"$(printf '%s' "$PROMPT" | sed 's/\\/\\\\/g; s/"/\\"/g')")

	curl_result=$(
		curl -sS \
			-o "$tmp_body" \
			-w '%{time_total},%{http_code}' \
			-H 'Content-Type: application/json' \
			-d "$payload" \
			"$OLLAMA_URL/api/generate"
	)

	total_seconds="${curl_result%%,*}"
	http_code="${curl_result##*,}"
	ts="$(timestamp_utc)"
	line="$ts,$MODE_LABEL,$run,$OLLAMA_MODEL,$total_seconds,$http_code"
	echo "$line"
	append_csv "$line"

	if [ "$http_code" -ge 400 ]; then
		echo "Request failed (HTTP $http_code). Response body:" >&2
		cat "$tmp_body" >&2
		rm -f "$tmp_body"
		exit 1
	fi

	rm -f "$tmp_body"
done

