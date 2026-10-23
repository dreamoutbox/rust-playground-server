#!/usr/bin/env bash
# Shared helpers for provisioning rust-playground-server assets.
# Source this file; it does not run anything on its own.

_SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${_SHARED_DIR}"
ASSETS_DIR="${REPO_ROOT}/assets"
ARCH="$(uname -m)"
ALPINE_VERSION="3.22.0"

mkdir -p "${ASSETS_DIR}"

ensure_assets() {
    local fc_bin="${ASSETS_DIR}/firecracker"
    local kernel_link="${ASSETS_DIR}/vmlinux"
    local apk_bin="${ASSETS_DIR}/apk.static"

    if [ ! -x "${fc_bin}" ] || [ ! -e "${kernel_link}" ] || [ ! -x "${apk_bin}" ]; then
        echo "Base assets missing in ${ASSETS_DIR}. Running plan-3/setup.sh to provision them..."
        "${REPO_ROOT}/plan-3/setup.sh"
    fi
}

ensure_toolchain_rootfs() {
    local rootfs_img="${ASSETS_DIR}/rust-toolchain.ext4"
    local init_script="${REPO_ROOT}/guest-init/init.sh"

    if [ -f "${rootfs_img}" ] && [ "${rootfs_img}" -nt "${init_script}" ]; then
        echo "Toolchain rootfs ${rootfs_img} is up-to-date."
        return 0
    fi

    local tarball="${ASSETS_DIR}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz"
    if [ ! -f "${tarball}" ]; then
        echo "Downloading Alpine minirootfs ${ALPINE_VERSION}..."
        local download_url="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION%.*}/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz"
        curl -fsSL "${download_url}" -o "${tarball}"
    fi

    local extract_dir="${ASSETS_DIR}/rust-toolchain-rootfs"
    rm -rf "${extract_dir}"
    mkdir -p "${extract_dir}"

    echo "Extracting Alpine minirootfs..."
    tar -xzf "${tarball}" -C "${extract_dir}"

    echo "Installing Rust toolchain into toolchain rootfs using apk.static..."
    # Skip package scripts/triggers: non-root apk wraps them in unshare(), which
    # GitHub runners forbid. The minirootfs already has the busybox symlinks and
    # the guest builds offline, so no trigger work is needed.
    "${ASSETS_DIR}/apk.static" \
        --root "${extract_dir}" \
        --no-progress \
        add --no-scripts rust cargo

    echo "Installing guest /init..."
    cp "${init_script}" "${extract_dir}/init"
    chmod +x "${extract_dir}/init"

    echo "Creating /workspace mount point directory..."
    mkdir -p "${extract_dir}/workspace"

    echo "Building ${rootfs_img} (1GB ext4)..."
    truncate -s 1G "${rootfs_img}"
    mkfs.ext4 -q -F -d "${extract_dir}" "${rootfs_img}"

    rm -rf "${extract_dir}"
}

# Ensure command is installed, if not found install with apt
# Usage: ensure_cmd <command> <apt-package>
ensure_cmd() {
    local cmd=$1 pkg=$2 sudo=

    # Search sbin dirs too: non-root PATH often omits them
    if command -v "$cmd" >/dev/null 2>&1 || [ -x "/sbin/$cmd" ] || [ -x "/usr/sbin/$cmd" ]; then
        return 0
    fi

    [ "$(id -u)" -eq 0 ] || sudo=sudo

    echo "Installing $pkg (provides $cmd)..." >&2
    $sudo env DEBIAN_FRONTEND=noninteractive apt-get update -qq &&
    $sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg" || {
        echo "Failed to install $pkg" >&2
        return 1
    }

    command -v "$cmd" >/dev/null 2>&1 || [ -x "/sbin/$cmd" ] || [ -x "/usr/sbin/$cmd" ]
}
