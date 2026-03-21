#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

COMPOSE_FILES=(
  "caddy/docker-compose.yml"
  "dashy/docker-compose.yml"
  "dev-dbs/docker-compose.yml"
  "freshrss/docker-compose.yml"
  "immich-app/docker-compose.yml"
  "mongo-db/docker-compose.yml"
  "netdata/docker-compose.yml"
  "paperless-ngx/docker-compose.yml"
  "portainer/docker-compose.yml"
  "portracker/docker-compose.yml"
  "stirling-pdf/docker-compose.yml"
  "uptime-kuma/docker-compose.yml"
  "vaultwarden/docker-compose.yml"
)

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_yamllint() {
  if ! have_cmd yamllint; then
    echo "Skipping yamllint: command not found"
    return 0
  fi

  echo "==> yamllint"
  (
    cd "$ROOT_DIR"
    yamllint -c .yamllint.yml "${COMPOSE_FILES[@]}" .env.global
  )
}

run_compose_config() {
  if ! have_cmd docker; then
    echo "Skipping docker compose config: docker command not found"
    return 0
  fi

  local compose_file
  for compose_file in "${COMPOSE_FILES[@]}"; do
    if [[ ! -s "$ROOT_DIR/$compose_file" ]]; then
      echo "Skipping $compose_file: file missing or empty"
      continue
    fi

    echo "==> docker compose config: $compose_file"
    (
      cd "$ROOT_DIR/$(dirname "$compose_file")"
      docker compose -f "$(basename "$compose_file")" config >/dev/null
    )
  done
}

run_yamllint
run_compose_config

echo "Compose lint finished"
