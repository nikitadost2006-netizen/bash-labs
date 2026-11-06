# http-probe (Сетевой монитор)

Утилита для периодической проверки HTTP-сервисов с экспортом метрик.

## Запуск

```bash
./http-probe --input services.conf
./http-probe --input services.conf --format jsonl
./http-probe --input services.conf --format prometheus
./http-probe --input services.conf --interval 60