# run-supervised (Супервизор процессов)

Утилита для запуска дочерних команд с контролем времени выполнения, повторными попытками (retries) и сбором метаданных.

## Запуск

```bash
./run-supervised --timeout 10s --log-dir ./logs -- echo "Hello"
./run-supervised --timeout 2s --log-dir ./logs -- sleep 10
./run-supervised --timeout 5s --retries 3 --log-dir ./logs -- bash -c "exit 1"