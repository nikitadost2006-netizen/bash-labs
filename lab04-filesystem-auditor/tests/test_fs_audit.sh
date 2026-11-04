#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/fs-audit"
POLICY="$ROOT_DIR/fixtures/policy.conf"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

total=0; fail=0
ok()  { total=$((total+1)); echo "ok $total - $1"; }
not() { total=$((total+1)); fail=$((fail+1)); echo "not ok $total - $1"; }

# 1 help
if "$SCRIPT" --help 2>&1 | grep -q 'Usage:'; then ok "help"; else not "help"; fi

# 2 missing args
if "$SCRIPT" >/dev/null 2>&1; then not "missing args"; else ok "missing args"; fi

# 3 clean dir (violations = 0)
mkdir -p "$TMP/clean"
touch "$TMP/clean/file.txt"
ec=0; "$SCRIPT" --root "$TMP/clean" --policy "$POLICY" >/dev/null 2>&1 || ec=$?
if [[ $ec -eq 0 ]]; then ok "clean dir returns 0"; else not "clean dir returns 0"; fi

mkdir -p "$TMP/bad"

# 4 world writable
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  ok "finds world writable (skipped on Windows)"
else
  touch "$TMP/bad/ww.txt"
  chmod 666 "$TMP/bad/ww.txt"
  ec=0; "$SCRIPT" --root "$TMP/bad" --policy "$POLICY" >/dev/null 2>&1 || ec=$?
  if [[ $ec -eq 1 ]]; then ok "finds world writable"; else not "finds world writable"; fi
fi

# 5 bad extension
touch "$TMP/bad/file.exe"
out=$("$SCRIPT" --root "$TMP/bad" --policy "$POLICY" 2>/dev/null || true)
if echo "$out" | grep -q 'BAD_EXTENSION'; then ok "finds bad ext"; else not "finds bad ext"; fi

# 6 json format
out_json=$("$SCRIPT" --root "$TMP/bad" --policy "$POLICY" --format json 2>/dev/null || true)
if echo "$out_json" | grep -q '"id": "BAD_EXTENSION"'; then ok "json output"; else not "json output"; fi

# 7 missing policy file
if "$SCRIPT" --root "$TMP/bad" --policy "$TMP/nope.conf" >/dev/null 2>&1; then not "missing policy"; else ok "missing policy"; fi

# 8 root not a directory
if "$SCRIPT" --root "$TMP/nope" --policy "$POLICY" >/dev/null 2>&1; then not "bad root dir"; else ok "bad root dir"; fi

# 9 invalid format
if "$SCRIPT" --root "$TMP/bad" --policy "$POLICY" --format xml >/dev/null 2>&1; then not "invalid format"; else ok "invalid format"; fi

# 10 size too large
echo "max_size=1" > "$TMP/policy_max.conf"
touch "$TMP/bad/large.txt"
echo "12345" > "$TMP/bad/large.txt"
out_max=$("$SCRIPT" --root "$TMP/bad" --policy "$TMP/policy_max.conf" 2>/dev/null || true)
if echo "$out_max" | grep -q 'SIZE_TOO_LARGE'; then ok "size too large"; else not "size too large"; fi

echo "1..$total"
(( fail == 0 ))