#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/parallel-run"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

total=0; fail=0
ok()  { total=$((total+1)); echo "ok $total - $1"; }
not() { total=$((total+1)); fail=$((fail+1)); echo "not ok $total - $1"; }

# 1 help
if "$SCRIPT" --help 2>&1 | grep -q 'Usage:'; then ok "help"; else not "help"; fi

# 2 missing args
if "$SCRIPT" >/dev/null 2>&1; then not "missing args"; else ok "missing args"; fi

# 3 simple task
echo -e "t1\techo 'hello'" > "$TMP/tasks1.tsv"
if "$SCRIPT" --tasks "$TMP/tasks1.tsv" --log-dir "$TMP/logs1" >/dev/null 2>&1; then ok "simple task success"; else not "simple task success"; fi

# 4 results file has data
if grep -q "t1" "$TMP/logs1/results.tsv"; then ok "results file populated"; else not "results file populated"; fi

# 5 parallel limit (max 1)
# Создаем 2 задачи, которые спят 1 сек. При parallel 1 это займет >= 2 сек.
echo -e "t1\tsleep 1" > "$TMP/tasks2.tsv"
echo -e "t2\tsleep 1" >> "$TMP/tasks2.tsv"
START=$(date +%s)
"$SCRIPT" --tasks "$TMP/tasks2.tsv" --log-dir "$TMP/logs2" --parallel 1 >/dev/null 2>&1
END=$(date +%s)
if [[ $((END - START)) -ge 2 ]]; then ok "parallel limit enforced"; else not "parallel limit enforced"; fi

# 6 fail-fast (при падении первой задачи вторая не должна выполниться)
echo -e "t1\texit 1" > "$TMP/tasks3.tsv"
echo -e "t2\tsleep 2; echo done" >> "$TMP/tasks3.tsv"
"$SCRIPT" --tasks "$TMP/tasks3.tsv" --log-dir "$TMP/logs3" --parallel 1 --fail-fast >/dev/null 2>&1 || true
if [[ ! -f "$TMP/logs3/t2_stdout.log" ]]; then ok "fail-fast stops next tasks"; else not "fail-fast stops next tasks"; fi

# 7 keep-going (при падении первой задачи вторая выполняется)
"$SCRIPT" --tasks "$TMP/tasks3.tsv" --log-dir "$TMP/logs4" --parallel 1 --keep-going >/dev/null 2>&1 || true
if [[ -f "$TMP/logs4/t2_stdout.log" ]]; then ok "keep-going runs next tasks"; else not "keep-going runs next tasks"; fi

# 8 retries (задача падает, делаем 2 ретрая)
echo -e "t1\texit 1" > "$TMP/tasks4.tsv"
"$SCRIPT" --tasks "$TMP/tasks4.tsv" --log-dir "$TMP/logs5" --retries 2 >/dev/null 2>&1 || true
attempts=$(grep -c "Retrying" "$TMP/logs5/t1_stderr.log" || true)
if [[ "$attempts" -eq 2 ]]; then ok "retries work"; else not "retries work (got $attempts)"; fi

# 9 exit code of parallel-run
if "$SCRIPT" --tasks "$TMP/tasks1.tsv" --log-dir "$TMP/logs6" >/dev/null 2>&1; then ok "exit code 0 on success"; else not "exit code 0 on success"; fi

# 10 exit code on failure
if "$SCRIPT" --tasks "$TMP/tasks4.tsv" --log-dir "$TMP/logs7" >/dev/null 2>&1; then not "exit code 1 on failure"; else ok "exit code 1 on failure"; fi

echo "1..$total"
(( fail == 0 ))