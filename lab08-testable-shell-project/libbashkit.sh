#!/usr/bin/env bash

# 1. Логирование с уровнями
log_msg() {
  local level=$1
  local msg=$2
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[$ts] [$level] $msg" >&2
}

# 2. Создание временной рабочей области с автоочисткой
create_temp_workspace() {
  # Сохраняем путь в глобальную переменную
  BASHKIT_TMP_DIR=$(mktemp -d)
  # Ставим trap в текущем процессе (не в подпроцессе!)
  trap 'rm -rf "$BASHKIT_TMP_DIR"' EXIT INT TERM
}

# 3. Безопасная обработка NUL-разделенных путей
safe_process_paths() {
  local dir=$1
  local callback=$2
  while IFS= read -r -d '' file; do
    "$callback" "$file"
  done < <(find "$dir" -mindepth 1 -print0)
}

# 4. Повтор операции с backoff (экспоненциальная задержка)
retry_cmd() {
  local max_retries=$1
  shift
  local attempt=0
  local ec=0

  while (( attempt <= max_retries )); do
    if "$@"; then
      return 0
    else
      ec=$?
      attempt=$((attempt + 1))
      if (( attempt <= max_retries )); then
        local backoff=$(( 2 ** attempt ))
        log_msg "WARN" "Command '$*' failed (code $ec). Retry $attempt/$max_retries in ${backoff}s..."
        sleep "$backoff"
      fi
    fi
  done
  return $ec
}

# 5. Чтение конфигурации (key=value)
get_config_val() {
  local file=$1
  local key=$2
  local default=$3
  local val
  val=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | tr -d '\r' | xargs)
  echo "${val:-$default}"
}

# 6. Проверка обязательных команд
check_required_cmds() {
  local missing=0
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log_msg "ERROR" "Required command not found: $cmd"
      missing=$((missing + 1))
    fi
  done
  return $missing
}

# 7. Безопасное формирование JSON (экранирование)
json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  echo "$s"
}