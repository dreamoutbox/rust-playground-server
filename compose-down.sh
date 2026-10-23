#!/usr/bin/env bash
# Start the Rust Playground Server using Docker Compose.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"

COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

echo "Stopping playground server..."
docker compose -f "${COMPOSE_FILE}" down "$@"
