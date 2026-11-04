#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/file-index"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

pass=0
fail=0

ok()  { pass=$((pass+1)); echo "ok $pass - $1"; }
not() { fail=$((fail+1)); echo "not ok - $1"; }

mkdir -p "$TMP/empty" "$TMP/data" "$TMP/weird"

if "$SCRIPT" --help 2>&1 | grep -q 'Usage:'; then ok "help"; else not "help"; fi
if "$SCRIPT" --version 2>&1 | grep -q 'file-index'; then ok "version"; else not "version"; fi
if "$SCRIPT" --output "$TMP/x" >/dev/null 2>&1; then not "missing root"; else ok "missing root"; fi
if "$SCRIPT" --root "$TMP/nope" --output "$TMP/x" >/dev/null 2>&1; then not "nonexistent root"; else ok "nonexistent root"; fi

"$SCRIPT" --root "$TMP/empty" --output "$TMP/empty.csv" >/dev/null 2>&1
if [[ $(wc -l < "$TMP/empty.csv") -eq 1 ]]; then ok "empty dir header"; else not "empty dir header"; fi

printf 'hello' > "$TMP/data/a.txt"
"$SCRIPT" --root "$TMP/data" --output "$TMP/out.csv" >/dev/null 2>&1
if grep -q 'a.txt' "$TMP/out.csv" && [[ $(awk -F, 'NR==2{print NF}' "$TMP/out.csv") -eq 7 ]]; then ok "csv regular"; else not "csv regular"; fi

"$SCRIPT" --root "$TMP/data" --output "$TMP/out.jsonl" --format jsonl >/dev/null 2>&1
if grep -q '"path":' "$TMP/out.jsonl" && grep -q '"sha256":' "$TMP/out.jsonl"; then ok "jsonl"; else not "jsonl"; fi

touch "$TMP/weird/a b"$'\n'"c.txt"
"$SCRIPT" --root "$TMP/weird" --output "$TMP/weird.jsonl" --format jsonl >/dev/null 2>&1
if grep -q 'a b\\nc.txt' "$TMP/weird.jsonl"; then ok "newline escaped"; else not "newline escaped"; fi

touch "$TMP/data/skip.tmp"
"$SCRIPT" --root "$TMP/data" --output "$TMP/ex.csv" --exclude '*.tmp' >/dev/null 2>&1
if ! grep -q 'skip.tmp' "$TMP/ex.csv"; then ok "exclude"; else not "exclude"; fi

dd if=/dev/zero of="$TMP/data/big.bin" bs=1 count=100 2>/dev/null
"$SCRIPT" --root "$TMP/data" --output "$TMP/max.csv" --max-size 10 >/dev/null 2>&1
if ! grep -q 'big.bin' "$TMP/max.csv"; then ok "max-size"; else not "max-size"; fi

rm -f "$TMP/dry.csv"
"$SCRIPT" --root "$TMP/data" --output "$TMP/dry.csv" --dry-run >/dev/null 2>&1
if [[ ! -e "$TMP/dry.csv" ]]; then ok "dry-run"; else not "dry-run"; fi

if "$SCRIPT" --root "$TMP/data" --output "$TMP/x" --format xml >/dev/null 2>&1; then not "invalid format"; else ok "invalid format"; fi

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  ok "unreadable warn (skipped on Windows)"
elif [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  touch "$TMP/data/noread"
  chmod 000 "$TMP/data/noread"
  "$SCRIPT" --root "$TMP/data" --output "$TMP/noread.csv" 2>"$TMP/err" >/dev/null || true
  if grep -q 'Cannot compute SHA-256' "$TMP/err"; then
    ok "unreadable warn"
  else
    not "unreadable warn"
  fi
  chmod 600 "$TMP/data/noread"
else
  ok "unreadable skipped as root"
fi

echo "1..$((pass+fail))"
(( fail == 0 ))
