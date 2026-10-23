#!/usr/bin/env bash
# Setup artifacts and environment for rust-playground-server.
# Builds assets/rust-toolchain.ext4 (read-only base image with Rust toolchain and guest init).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared.sh
. "${SCRIPT_DIR}/shared.sh"

TARGET_USER="${SUDO_USER:-$USER}"

fix_ownership() {
    if [ -n "${SUDO_USER:-}" ] && [ "$EUID" -eq 0 ]; then
        chown -R "${SUDO_USER}:${SUDO_USER}" "${ASSETS_DIR}" 2>/dev/null || true
    fi
}

main() {
    ensure_cmd truncate   coreutils  || exit 1
    ensure_cmd mkfs.ext4  e2fsprogs  || exit 1

    ensure_assets
    ensure_toolchain_rootfs
    fix_ownership

    echo "rust-playground-server setup complete:"
    echo "Toolchain rootfs: assets/rust-toolchain.ext4"
}

main "$@"
