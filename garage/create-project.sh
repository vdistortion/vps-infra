#!/bin/bash
# Create a Garage bucket + API key for a project and grant full access.
# Run on the VPS where the Garage container lives.
#
# Usage: ./create-project.sh <project-name>
# Example: ./create-project.sh myproject
#
# Prints the Key ID and Secret key of a NEW key — put them into the project's
# GitHub Actions secrets as GARAGE_ACCESS_KEY_ID and GARAGE_SECRET_ACCESS_KEY
# (GARAGE_BUCKET = project name).
#
# Garage показывает Secret key только в момент создания ключа
# (`garage key info` выдаёт (redacted)), поэтому сохраните его сразу.
#
# Скрипт идемпотентен: если бакет/ключ уже существуют, создание пропускается.

set -euo pipefail

NAME="${1:?Usage: $0 <project-name>}"

if docker exec garage /garage bucket info "$NAME" >/dev/null 2>&1; then
  echo "Бакет '$NAME' уже существует — создание пропущено."
else
  docker exec garage /garage bucket create "$NAME"
fi

if docker exec garage /garage key info "$NAME" >/dev/null 2>&1; then
  echo "Ключ '$NAME' уже существует — его Secret key показать нельзя"
  echo "(секрет отдаётся один раз, при создании ключа)."
  echo "Если секрет утерян — создайте новый ключ вручную:"
  echo "  docker exec garage /garage key create <имя>"
else
  KEY_OUTPUT="$(docker exec garage /garage key create "$NAME")"
  echo
  echo "Credentials for '$NAME' (store securely; the secret is shown only once):"
  echo "$KEY_OUTPUT"
fi

docker exec garage /garage bucket allow --read --write --owner "$NAME" --key "$NAME"