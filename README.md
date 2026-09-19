# vps-infra

Общая инфраструктура для всех проектов на VPS. Каждый сервис —
отдельная директория со своим `compose.yaml` и README. Проекты
подключаются к сервисам через external Docker-сети.

## Состав

| Сервис | Сеть | Назначение |
|---|---|---|
| [Caddy](caddy/) | `caddy` | Reverse proxy, автоматический SSL, маршрутизация по доменам |
| [Garage](garage/) | `garage` | Self-hosted S3-хранилище |

## Быстрый старт на новом VPS

```bash
# apt update && apt upgrade -y && apt install -y nodejs npm && curl -fsSL https://get.docker.com | sh

git clone https://github.com/vdistortion/vps-infra.git ~/vps-infra

# 1. Caddy
docker network create caddy
cd ~/vps-infra/caddy
docker compose up -d

# 2. Garage
docker network create garage   # создаётся compose, но можно и вручную
cd ~/vps-infra/garage
cp garage.toml.example garage.toml
# вписать секреты в garage.toml
docker compose up -d
docker exec garage /garage status
```

## Подключение нового проекта

Проект не зависит от этого репозитория как субмодуля. Он объявляет
нужные сети как `external: true` и подключается к ним:

```yaml
networks:
  caddy:
    external: true
  garage:
    external: true
```

Для Garage — создать бакет и ключ через `garage/create-project.sh`,
прописать их в секреты GitHub Actions. Для Caddy — просто добавить
лейблы `caddy:` и `caddy.reverse_proxy:` в сервисы проекта.

Подробности — в README каждого сервиса.
