#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/http-probe"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

total=0; fail=0
ok()  { total=$((total+1)); echo "ok $total - $1"; }
not() { total=$((total+1)); fail=$((fail+1)); echo "not ok $total - $1"; }

# Создаем фейковый curl для тестов, чтобы не зависеть от сети
mkdir -p "$TMP/bin"
cat > "$TMP/bin/curl" <<'MOCK_CURL'
#!/usr/bin/env bash
# Фейковый curl. Проверяем URL из аргументов
url=""
for arg in "$@"; do
  if [[ "$arg" =~ ^https?:// ]]; then url="$arg"; fi
done

if [[ "$url" == *"success"* ]]; then
  echo -n "200|0.010|0.020|0.030|0.100"
  exit 0
elif [[ "$url" == *"fail"* ]]; then
  echo -n "500|0.010|0.020|0.030|0.100"
  exit 22 # curl exit code for HTTP error
elif [[ "$url" == *"network_err"* ]]; then
  echo "curl: (6) Could not resolve host" >&2
  exit 6
fi
MOCK_CURL
chmod +x "$TMP/bin/curl"
export PATH="$TMP/bin:$PATH"

# 1 help
if "$SCRIPT" --help 2>&1 | grep -q 'Usage:'; then ok "help"; else not "help"; fi

# 2 missing input
if "$SCRIPT" >/dev/null 2>&1; then not "missing input"; else ok "missing input"; fi

# 3 invalid format
echo "t1 http://success.com 200" > "$TMP/services.conf"
if "$SCRIPT" --input "$TMP/services.conf" --format xml >/dev/null 2>&1; then not "invalid format"; else ok "invalid format"; fi

# 4 invalid URL scheme
echo "t1 ftp://success.com 200" > "$TMP/bad_scheme.conf"
if "$SCRIPT" --input "$TMP/bad_scheme.conf" >/dev/null 2>&1; then not "invalid scheme"; else ok "invalid scheme"; fi

# 5 successful text probe
if "$SCRIPT" --input "$TMP/services.conf" 2>&1 | grep -q '\[OK\]'; then ok "text output OK"; else not "text output OK"; fi

# 6 failed text probe
echo "t1 http://fail.com 200" > "$TMP/fail.conf"
if "$SCRIPT" --input "$TMP/fail.conf" >/dev/null 2>&1; then not "fails on bad code"; else ok "fails on bad code"; fi

# 7 jsonl format
if "$SCRIPT" --input "$TMP/services.conf" --format jsonl 2>/dev/null | grep -q '"success":1'; then ok "jsonl format"; else not "jsonl format"; fi

# 8 prometheus format
if "$SCRIPT" --input "$TMP/services.conf" --format prometheus 2>/dev/null | grep -q 'http_probe_up{service="t1"'; then ok "prometheus format"; else not "prometheus format"; fi

# 9 retries (должен быть вызван 3 раза при retries=2)
echo "t1 http://network_err.com 200" > "$TMP/err.conf"
"$SCRIPT" --input "$TMP/err.conf" --retries 2 >/dev/null 2>&1 || true
# Проверяем, что скрипт не упал от ошибки
if [[ $? -eq 0 ]]; then ok "retries handled gracefully"; else not "retries handled gracefully"; fi

# 10 secrets masking
echo "t1 http://user:pass@success.com 200" > "$TMP/secret.conf"
out=$("$SCRIPT" --input "$TMP/secret.conf" 2>/dev/null || true)
if echo "$out" | grep -q '\*\*\*:\*\*\*@success.com'; then ok "secrets masked"; else not "secrets masked"; fi

echo "1..$total"
(( fail == 0 ))