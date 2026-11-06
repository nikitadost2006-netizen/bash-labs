# incident-collect (Сборщик диагностики инцидентов)

Утилита для первичной диагностики сервера. Собирает данные о состоянии системы и формирует отчеты в формате Markdown и JSON.

## Запуск

```bash
./incident-collect --output ./report_dir --window 5m --service https://example.com --log /var/log/syslog --redact-config redact.conf