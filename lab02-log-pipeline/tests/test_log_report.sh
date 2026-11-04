#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/log-report"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

total=0; fail=0
ok()  { total=$((total+1)); echo "ok $total - $1"; }
not() { total=$((total+1)); fail=$((fail+1)); echo "not ok $total - $1"; }

# Генерируем лог для тестов
"$ROOT_DIR/fixtures/gen_logs.sh" 1000 > "$TMP/access.log"

# 1 help
if "$SCRIPT" --help 2>&1 | grep -q 'Usage:'; then ok "help"; else not "help"; fi

# 2 version
if "$SCRIPT" --version 2>&1 | grep -q 'log-report'; then ok "version"; else not "version"; fi

# 3 missing input
if "$SCRIPT" >/dev/null 2>&1; then not "missing input"; else ok "missing input"; fi

# 4 nonexistent input
if "$SCRIPT" --input "$TMP/nope.log" >/dev/null 2>&1; then not "nonexistent input"; else ok "nonexistent input"; fi

# 5 invalid format
if "$SCRIPT" --input "$TMP/access.log" --format xml >/dev/null 2>&1; then not "invalid format"; else ok "invalid format"; fi

# 6 text output
out=$("$SCRIPT" --input "$TMP/access.log" 2>/dev/null)
if echo "$out" | grep -q '=== Log Report ===' && echo "$out" | grep -q 'Top 10 URLs:'; then ok "text output"; else not "text output"; fi

# 7 json output
out_json=$("$SCRIPT" --input "$TMP/access.log" --format json 2>/dev/null)
if echo "$out_json" | grep -q '"total_requests":' && echo "$out_json" | grep -q '"top_urls":'; then ok "json output"; else not "json output"; fi

# 8 strict mode (должен упасть)
if "$SCRIPT" --input "$TMP/access.log" --strict >/dev/null 2>&1; then not "strict mode fails on bad line"; else ok "strict mode fails on bad line"; fi

# 9 top N
out_top=$("$SCRIPT" --input "$TMP/access.log" --top 2 2>/dev/null)
if echo "$out_top" | grep -q 'Top 2 URLs:'; then ok "top N"; else not "top N"; fi

# 10 stdin
out_stdin=$(cat "$TMP/access.log" | "$SCRIPT" --input - 2>/dev/null)
if echo "$out_stdin" | grep -q 'Total Requests:'; then ok "stdin"; else not "stdin"; fi

echo "1..$total"
(( fail == 0 ))