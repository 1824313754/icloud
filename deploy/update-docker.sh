#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
docker compose pull icloud
docker compose up -d --no-build --wait --wait-timeout 120 icloud
