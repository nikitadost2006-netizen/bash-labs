#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/run-supervised"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

total=0; fail=0
ok()  { total=$((total+1)); echo "ok $total - $1"; }
not() { total=$((total+1)); fail=$((fail+1)); echo "not ok $total - $1"; }

# 1 help
if "$SCRIPT" --help 2>&1 | grep -q 'Usage:'; then ok "help"; else not "help"; fi

# 2 success
if "$SCRIPT" --timeout 5s --log-dir "$TMP/logs1" -- bash -c 'exit 0' >/dev/null 2>&1; then ok "success"; else not "success"; fi

# 3 failure (код 17)
ec=0
"$SCRIPT" --timeout 5s --log-dir "$TMP/logs2" -- bash -c 'exit 17' >/dev/null 2>&1 || ec=$?
if [[ $ec -eq 1 ]]; then ok "failure returns 1"; else not "failure returns 1"; fi

# 4 timeout
ec=0
"$SCRIPT" --timeout 1s --log-dir "$TMP/logs3" -- sleep 5 >/dev/null 2>&1 || ec=$?
if [[ $ec -eq 1 ]]; then ok "timeout"; else not "timeout"; fi

# 5 retries count (должно быть 3 файла meta для 2 ретраев)
ec=0
"$SCRIPT" --timeout 1s --retries 2 --log-dir "$TMP/logs4" -- bash -c 'exit 1' >/dev/null 2>&1 || ec=$?
cnt=$(ls "$TMP/logs4"/*_meta.json 2>/dev/null | wc -l)
if [[ $cnt -eq 3 ]]; then ok "retries count (3 files)"; else not "retries count (got $cnt)"; fi

# 6 meta json valid
if grep -q '"status": "success"' "$TMP/logs1/attempt_0_meta.json"; then ok "meta json valid"; else not "meta json valid"; fi

echo "1..$total"
(( fail == 0 ))