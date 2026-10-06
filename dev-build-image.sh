#!/usr/bin/env bash
# Build the Rust Playground Server Docker image.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"
IMAGE_NAME="dreamoutbox/rust-playground-server:latest"

# Ensure base assets and toolchain rootfs are built on host
"${SCRIPT_DIR}/setup.sh"

echo "Building Docker image ${IMAGE_NAME}..."
docker build -f "${SCRIPT_DIR}/Dockerfile" -t ${IMAGE_NAME} "${REPO_ROOT}" "$@"

echo "Docker image built successfully: ${IMAGE_NAME}"
