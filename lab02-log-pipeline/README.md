# log-report

Анализатор логов HTTP-сервера (формат, близкий к Combined Log Format).

## Запуск

```bash
./log-report --input access.log
./log-report --input access.log --format json
./log-report --input access.log --top 5
cat access.log | ./log-report --input -