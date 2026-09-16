# Garage — self-hosted S3-хранилище

Self-hosted S3-совместимое объектное хранилище. Запускается как
общий сервис на VPS — точно так же, как Caddy. Каждый проект
подключается через docker-сеть `garage` и хранит файлы в своём
бакете со своим API-ключом. Изоляция данных — через бакет и ключи,
а не через URL.

---

## Требования

- Docker Engine 24+, Docker Compose v2
- Запущенный Caddy (см. `../caddy/README.md`) — не обязателен для
  самого Garage, но нужен проектам, которые раздают файлы наружу
  через Directus

---

## Структура

- `garage.toml.example` — шаблон конфигурации Garage.
- `compose.yaml` — single-node стек Garage; создаёт сеть `garage`.
- `create-project.sh` — создаёт бакет + ключ для одного проекта.

---

## Первичная установка (на VPS)

### 1. Подготовить конфиг

```bash
cd ~/vps-infra/garage
cp garage.toml.example garage.toml
```

Заменить три секрета в `garage.toml` на сгенерированные:

```bash
# rpc_secret — 32 байта hex
openssl rand -hex 32

# admin_token и metrics_token — base64
openssl rand -base64 32
openssl rand -base64 32
```

Вписать значения в `garage.toml` вручную или через `sed`:

```bash
RPC=$(openssl rand -hex 32)
ADMIN=$(openssl rand -base64 32)
METRICS=$(openssl rand -base64 32)
sed -i "s/REPLACE_WITH_rpc_secret/$RPC/" garage.toml
sed -i "s/REPLACE_WITH_admin_token/$ADMIN/" garage.toml
sed -i "s/REPLACE_WITH_metrics_token/$METRICS/" garage.toml
```

Файл `garage.toml` с реальными секретами **не коммитить** — он
в `.gitignore` (если нет, добавить).

### 2. Запустить

```bash
docker compose up -d
```

Проверить, что нода здорова:

```bash
docker exec garage /garage status
```

Должен показать одну `HEALTHY NODE` с версией `v2.3.0`.

Флаг `--single-node` (Garage >= v2.3.0) автоматически настраивает
cluster layout, поэтому `garage layout assign/apply` не нужен.

---

## Подключение проекта

```bash
cd ~/vps-infra/garage
./create-project.sh myproject
```

Скрипт создаёт бакет `myproject`, API-ключ с тем же именем,
выдаёт ему права на чтение и запись, и выводит `Key ID` и
`Secret key`.

Затем в репозитории проекта (GitHub → Settings → Secrets and
variables → Actions) добавить три секрета:

- `GARAGE_BUCKET` = `myproject`
- `GARAGE_ACCESS_KEY_ID` = выведенный `Key ID`
- `GARAGE_SECRET_ACCESS_KEY` = выведенный `Secret key`

Проект подключается к сети `garage` и обращается к S3 API по
адресу `http://garage:3900`. Публичный URL или проброс хост-порта
не нужен — Directus раздаёт файлы через свой эндпоинт `/assets`.

### Пример подключения в compose проекта

```yaml
services:
  app:
    environment:
      STORAGE_LOCATIONS: local,garage
      STORAGE_DEFAULT_LOCATION: garage
      STORAGE_GARAGE_DRIVER: s3
      STORAGE_GARAGE_KEY: ${GARAGE_ACCESS_KEY_ID}
      STORAGE_GARAGE_SECRET: ${GARAGE_SECRET_ACCESS_KEY}
      STORAGE_GARAGE_BUCKET: ${GARAGE_BUCKET}
      STORAGE_GARAGE_ENDPOINT: http://garage:3900
      STORAGE_GARAGE_REGION: garage
      STORAGE_GARAGE_FORCE_PATH_STYLE: 'true'
    networks:
      - internal
      - garage

networks:
  internal:
  garage:
    external: true
```

---

## Доступ к S3 с локальной машины (для миграций)

S3-порт привязан только к loopback VPS (`127.0.0.1:3900`), наружу он не
торчит. С локальной машины бакет проекта достаётся через SSH-туннель:

```bash
ssh -L 3900:127.0.0.1:3900 <vps>
# теперь http://127.0.0.1:3900 ведёт в Garage
```

Дальше обычным S3-клиентом (`rclone`, `awscli`, `mc`) с ключом проекта:

```bash
rclone copy garage:myproject /backup/myproject
```

---

## Управление

```bash
# Статус кластера
docker exec garage /garage status

# Список бакетов
docker exec garage /garage bucket list

# Список ключей
docker exec garage /garage key list

# Информация о конкретном бакете
docker exec garage /garage bucket info myproject

# Перезапуск
docker compose restart garage

# Обновление образа Garage
docker compose pull && docker compose up -d
```

---

## Обновление

Перед переходом через мажорные версии читать release notes:
<https://garagehq.deuxfleurs.fr/documentation/operations/upgrading/>

```bash
cd ~/vps-infra/garage
docker compose pull
docker compose up -d
docker exec garage /garage status
```

---

## Бэкапы

Автоматическое расписание бэкапов в этом репозитории пока не настроено.
Garage хранит метаданные и данные в volume `garage_meta` и `garage_data`.
До появления отдельной backup-системы их нужно сохранять вручную:

1. **На уровне volume** — средствами резервного копирования Docker volume.
2. **На уровне S3** — через `rclone`, настроенный на Garage. Для запуска с
   локальной машины сначала поднимите SSH-туннель из раздела выше, затем
   скопируйте бакет на отдельный диск или удалённое хранилище:

```bash
rclone copy garage:myproject /backup/myproject
```

Для production желательно сохранять и PostgreSQL-дампы проекта, и данные
Garage в независимое off-site-хранилище. Один только Docker volume на том же
VPS не защищает от потери VPS.

---

## Диагностика

**Garage не отвечает** — проверить что контейнер запущен и
`garage.toml` смонтирован корректно:

```bash
docker compose logs garage
docker exec garage /garage status
```

**Проект не может писать в Garage** — проверить что контейнер
проекта подключён к сети `garage` (`docker inspect <container>`)
и что `STORAGE_GARAGE_ENDPOINT` указывает на `http://garage:3900`.

**`create-project.sh` падает с ошибкой** — Garage должен быть
запущен до вызова скрипта. Проверить `docker exec garage /garage status`.
