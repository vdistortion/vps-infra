#!/bin/bash
# Create a Garage bucket + API key for a project and grant full access.
# Run on the VPS where the Garage container lives.
#
# Usage: ./create-project.sh <project-name>
# Example: ./create-project.sh myproject
#
# Prints the Key ID and Secret key — put them into the project's GitHub
# Actions secrets as GARAGE_BUCKET, GARAGE_ACCESS_KEY_ID, GARAGE_SECRET_ACCESS_KEY.

set -euo pipefail

NAME="${1:?Usage: $0 <project-name>}"

docker exec garage /garage bucket create "$NAME"
docker exec garage /garage key create "$NAME"
docker exec garage /garage bucket allow --read --write --owner "$NAME" --key "$NAME"

echo
echo "Credentials for '$NAME' (store securely):"
docker exec garage /garage key info "$NAME"
