#!/usr/bin/env bash
set -Eeuo pipefail

LINES=${1:-100000}
OUTPUT=${2:-/dev/stdout}

# Наборы данных для генерации
IPS=("192.168.1.1" "10.0.0.5" "8.8.8.8" "2001:db8::1" "1.1.1.1" "172.16.0.10")
METHODS=("GET" "POST" "PUT" "DELETE")
PATHS=("/index.html" "/api/v1/users" "/login?user=admin" "/images/logo.png" "/api/v1/items?page=2&limit=50")
STATUSES=("200" "200" "200" "301" "302" "400" "403" "404" "500" "502")
SIZES=("1024" "512" "0" "2048" "4096" "156" "890")

for ((i=1; i<=LINES; i++)); do
  # 1% битых строк
  if (( RANDOM % 100 == 0 )); then
    echo "MALFORMED LOG LINE $RANDOM" >> "$OUTPUT"
    continue
  fi

  ip=${IPS[RANDOM % ${#IPS[@]}]}
  method=${METHODS[RANDOM % ${#METHODS[@]}]}
  path=${PATHS[RANDOM % ${#PATHS[@]}]}
  status=${STATUSES[RANDOM % ${#STATUSES[@]}]}
  size=${SIZES[RANDOM % ${#SIZES[@]}]}
  
  # Время ответа от 10 до 2000 мс
  resp_time=$((RANDOM % 1990 + 10))
  
  # Время в формате ISO
  timestamp=$(date -u -d "@$(( $(date +%s) - RANDOM % 86400 ))" +"%Y-%m-%dT%H:%M:%SZ")

  # Формат: IP - - [TIME] "METHOD PATH HTTP/1.1" STATUS SIZE RESP_TIME
  echo "$ip - - [$timestamp] \"$method $path HTTP/1.1\" $status $size $resp_time" >> "$OUTPUT"
done
