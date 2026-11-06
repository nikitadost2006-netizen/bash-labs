# backupctl (Инкрементальная система резервного копирования)

Утилита для создания, проверки и восстановления резервных копий.

## Запуск

```bash
./backupctl init --repo my_repo
./backupctl create --repo my_repo --source my_source --label daily
./backupctl list --repo my_repo
./backupctl verify --repo my_repo --id <ID>
./backupctl restore --repo my_repo --id <ID> --target restored --dry-run
./backupctl prune --repo my_repo --keep 3 --dry-run