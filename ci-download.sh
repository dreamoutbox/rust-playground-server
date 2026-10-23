#!/usr/bin/env bash
# Provision base assets and the Rust toolchain rootfs (CI entrypoint).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=shared.sh
. "${SCRIPT_DIR}/shared.sh"

main() {
    ensure_assets
    ensure_toolchain_rootfs
}

main "$@"
