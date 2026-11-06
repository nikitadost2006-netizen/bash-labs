#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/backupctl"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

total=0; fail=0
ok()  { total=$((total+1)); echo "ok $total - $1"; }
not() { total=$((total+1)); fail=$((fail+1)); echo "not ok $total - $1"; }

# 1 help
if "$SCRIPT" --help 2>&1 | grep -q 'Usage:'; then ok "help"; else not "help"; fi

# 2 init
mkdir -p "$TMP/repo"
if "$SCRIPT" init --repo "$TMP/repo" 2>&1 | grep -q 'Initialized'; then ok "init"; else not "init"; fi

# 3 create
mkdir -p "$TMP/source"
echo "test" > "$TMP/source/a.txt"
if "$SCRIPT" create --repo "$TMP/repo" --source "$TMP/source" --label test 2>&1 | grep -q 'Backup created'; then ok "create"; else not "create"; fi

# Получаем ID созданного бэкапа
ID=$(ls "$TMP/repo/manifests"/*.tsv | head -n 1 | xargs basename | cut -d'.' -f1)

# 4 list
if "$SCRIPT" list --repo "$TMP/repo" 2>&1 | grep -q "$ID"; then ok "list"; else not "list"; fi

# 5 verify
if "$SCRIPT" verify --repo "$TMP/repo" --id "$ID" 2>&1 | grep -q 'OK'; then ok "verify success"; else not "verify success"; fi

# 6 verify corrupted
ARCH=$(ls "$TMP/repo/archives"/*.tar.gz)
echo "corrupt" >> "$ARCH"
if "$SCRIPT" verify --repo "$TMP/repo" --id "$ID" >/dev/null 2>&1; then not "verify corrupted fails"; else ok "verify corrupted fails"; fi

# ВАЖНО: Пересоздаем репозиторий и бэкап, так как предыдущий мы сломали
rm -rf "$TMP/repo" "$TMP/target"
mkdir -p "$TMP/repo"
"$SCRIPT" init --repo "$TMP/repo" >/dev/null 2>&1
"$SCRIPT" create --repo "$TMP/repo" --source "$TMP/source" --label test2 >/dev/null 2>&1
ID=$(ls "$TMP/repo/manifests"/*.tsv | head -n 1 | xargs basename | cut -d'.' -f1)

# 7 restore dry-run
if "$SCRIPT" restore --repo "$TMP/repo" --id "$ID" --target "$TMP/target" --dry-run > "$TMP/out7.log" 2>&1; then
  if grep -q 'DRY-RUN' "$TMP/out7.log"; then ok "restore dry-run"; else not "restore dry-run"; cat "$TMP/out7.log"; fi
else
  not "restore dry-run"; cat "$TMP/out7.log"
fi

# 8 restore actual
mkdir -p "$TMP/target"
if "$SCRIPT" restore --repo "$TMP/repo" --id "$ID" --target "$TMP/target" > "$TMP/out8.log" 2>&1; then 
  ok "restore actual"
else 
  not "restore actual"; cat "$TMP/out8.log"
fi

# 9 restored file exists
if [[ -f "$TMP/target/a.txt" ]]; then ok "restored file exists"; else not "restored file exists"; fi

# 10 prune dry-run
if "$SCRIPT" prune --repo "$TMP/repo" --keep 0 --dry-run 2>&1 | grep -q 'DRY-RUN'; then ok "prune dry-run"; else not "prune dry-run"; fi

echo "1..$total"
(( fail == 0 ))