#!/usr/bin/env bats

setup() {
  # Создаем временную папку для каждого теста
  TEST_DIR="$(mktemp -d)"
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CLI="$SCRIPT_DIR/bashkit"
  
  # Тестовые данные
  mkdir -p "$TEST_DIR/data"
  echo "test" > "$TEST_DIR/data/good.txt"
  echo "test" > "$TEST_DIR/data/bad.exe"
  echo "toolong" > "$TEST_DIR/data/large.txt"
  
  # Конфиг
  cat > "$TEST_DIR/config.conf" <<EOF
allowed_ext=.txt
max_size=5
EOF
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "CLI shows help" {
  run "$CLI" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "CLI fails without arguments" {
  run "$CLI"
  [ "$status" -eq 1 ]
}

@test "CLI validates files and creates JSON" {
  run "$CLI" --dir "$TEST_DIR/data" --config "$TEST_DIR/config.conf" --output "$TEST_DIR/report.json"
  [ "$status" -eq 0 ]
  
  # Проверяем, что файл создан
  [ -f "$TEST_DIR/report.json" ]
}

@test "JSON report contains correct statuses" {
  "$CLI" --dir "$TEST_DIR/data" --config "$TEST_DIR/config.conf" --output "$TEST_DIR/report.json"
  
  # good.txt должен быть ok
  run grep '"file":".*good.txt","status":"ok"' "$TEST_DIR/report.json"
  [ "$status" -eq 0 ]
  
  # bad.exe должен быть error (bad_extension)
  run grep '"reason":"bad_extension"' "$TEST_DIR/report.json"
  [ "$status" -eq 0 ]

  # large.txt должен быть error (size_too_large)
  run grep '"reason":"size_too_large"' "$TEST_DIR/report.json"
  [ "$status" -eq 0 ]
}

@test "Library function retry_cmd works" {
  # Тестируем функцию из библиотеки напрямую
  source "$SCRIPT_DIR/libbashkit.sh"
  
  # Команда false упадет 2 раза, потом true
  run retry_cmd 2 bash -c 'exit 1'
  [ "$status" -eq 1 ] # В итоге все равно упадет
  
  # Успешная команда
  run retry_cmd 2 true
  [ "$status" -eq 0 ]
}

@test "Library function json_escape works" {
  source "$SCRIPT_DIR/libbashkit.sh"
  run json_escape 'hello "world"'
  [ "$output" = 'hello \"world\"' ]
}