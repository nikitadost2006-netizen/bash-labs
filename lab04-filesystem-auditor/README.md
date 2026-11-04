# fs-audit (Аудитор файловой системы)

Утилита для проверки файловой системы на соответствие политике безопасности (INI-формат).

## Запуск

```bash
./fs-audit --root /path/to/dir --policy policy.conf
./fs-audit --root /path/to/dir --policy policy.conf --format json
./fs-audit --root /path/to/dir --policy policy.conf --fix --dry-run