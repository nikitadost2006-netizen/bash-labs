# file-index

Индексатор файлов в каталоге. Формирует CSV или JSONL с полями:

- absolute_path
- size
- mtime
- type
- sha256
- owner
- group

## Запуск

```bash
./file-index --help
./file-index --version

./file-index --root /tmp/data --output /tmp/index.csv

./file-index --root /tmp/data --output /tmp/index.jsonl \
    --format jsonl --exclude '*.tmp' --max-size 10485760

./file-index --root /tmp/data --output /tmp/index.csv --dry-run