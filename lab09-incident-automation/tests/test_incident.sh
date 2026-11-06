#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/incident-collect"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

total=0; fail=0
ok()  { total=$((total+1)); echo "ok $total - $1"; }
not() { total=$((total+1)); fail=$((fail+1)); echo "not ok $total - $1"; }

# 1 help
if "$SCRIPT" --help 2>&1 | grep -q 'Usage:'; then ok "help"; else not "help"; fi

# 2 missing args
if "$SCRIPT" >/dev/null 2>&1; then not "missing args"; else ok "missing args"; fi

# 3 dry-run creates no files
mkdir -p "$TMP/dry"
if "$SCRIPT" --output "$TMP/dry" --dry-run 2>&1 | grep -q 'DRY-RUN'; then 
  if [[ -z "$(ls -A "$TMP/dry")" ]]; then ok "dry-run creates no files"; else not "dry-run created files"; fi
else not "dry-run text"; fi

# 4 basic collection
mkdir -p "$TMP/report1"
if "$SCRIPT" --output "$TMP/report1" >/dev/null 2>&1; then ok "basic collection"; else not "basic collection"; fi
if [[ -f "$TMP/report1/report.md" && -f "$TMP/report1/report.json" ]]; then ok "reports created"; else not "reports created"; fi

# 6 existing dir protection
if "$SCRIPT" --output "$TMP/report1" >/dev/null 2>&1; then not "protects existing report"; else ok "protects existing report"; fi

# 7 log collection and redaction
mkdir -p "$TMP/report2"
echo "password=secret123" > "$TMP/test.log"
echo "password" > "$TMP/redact.conf"
"$SCRIPT" --output "$TMP/report2" --log "$TMP/test.log" --redact-config "$TMP/redact.conf" >/dev/null 2>&1
if grep -q "password=\*\*\*" "$TMP/report2/report.md"; then ok "redaction works"; else not "redaction works"; fi

# 8 checksums created
if [[ -f "$TMP/report2/checksums.sha256" ]]; then ok "checksums created"; else not "checksums created"; fi

# 9 http service probe (mock)
mkdir -p "$TMP/bin"
echo -e '#!/bin/bash\necho "200|0.1"' > "$TMP/bin/curl"
chmod +x "$TMP/bin/curl"
mkdir -p "$TMP/report3"
PATH="$TMP/bin:$PATH" "$SCRIPT" --output "$TMP/report3" --service "http://test" >/dev/null 2>&1
if grep -q "HTTP" "$TMP/report3/report.md"; then ok "http probe"; else not "http probe"; fi

# 10 exit code on partial fail (bad log file)
mkdir -p "$TMP/report4"
if "$SCRIPT" --output "$TMP/report4" --log "/nope/nope.log" >/dev/null 2>&1; then not "partial fail exit code"; else ok "partial fail exit code"; fi

echo "1..$total"
(( fail == 0 ))