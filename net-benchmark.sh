#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-./logs}"
mkdir -p "$OUT_DIR"
TS="$(date -u +%Y%m%d-%H%M%S)"
OUT_FILE="$OUT_DIR/net-benchmark-$TS.txt"

# 可按需增删
REGIONS=(
  "Tokyo|https://s3.ap-northeast-1.amazonaws.com"
  "Singapore|https://s3.ap-southeast-1.amazonaws.com"
  "Frankfurt|https://s3.eu-central-1.amazonaws.com"
  "London|https://s3.eu-west-2.amazonaws.com"
  "Virginia|https://s3.us-east-1.amazonaws.com"
  "California|https://s3.us-west-1.amazonaws.com"
  "Sydney|https://s3.ap-southeast-2.amazonaws.com"
)

{
  echo "# Net Benchmark"
  echo "UTC Time: $(date -u '+%F %T')"
  echo "Host: $(hostname)"
  echo
  printf "%-14s %12s %12s %12s\n" "Region" "Connect(ms)" "TTFB(ms)" "Total(ms)"

  for item in "${REGIONS[@]}"; do
    name="${item%%|*}"
    url="${item#*|}"

    if out=$(curl -o /dev/null -sS --max-time 20 -w "%{time_connect} %{time_starttransfer} %{time_total}" "$url" 2>/dev/null); then
      read -r tc ttfb tot <<< "$out"
      tc_ms=$(awk "BEGIN{printf \"%.1f\", $tc*1000}")
      ttfb_ms=$(awk "BEGIN{printf \"%.1f\", $ttfb*1000}")
      tot_ms=$(awk "BEGIN{printf \"%.1f\", $tot*1000}")
      printf "%-14s %12s %12s %12s\n" "$name" "$tc_ms" "$ttfb_ms" "$tot_ms"
    else
      printf "%-14s %12s %12s %12s\n" "$name" "ERR" "ERR" "ERR"
    fi
  done

  echo
  if command -v speedtest-cli >/dev/null 2>&1; then
    echo "# Local speedtest (nearest)"
    speedtest-cli --secure --simple || true
  else
    echo "# speedtest-cli not installed, skip throughput test"
  fi
} | tee "$OUT_FILE"

echo
echo "Saved: $OUT_FILE"
