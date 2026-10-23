#!/usr/bin/env bash
# Bootstrap: Docker Engine + Compose plugin, clone repo, docker compose up.
# Targets Debian/Ubuntu. Idempotent: safe to re-run (acts as a deploy).
#
# Usage:
#   REPO_URL=git@github.com:you/app.git ./bootstrap.sh
#   REPO_URL=... BRANCH=main APP_DIR=/opt/app APP_USER=deploy ./bootstrap.sh
set -euo pipefail

REPO_URL="${REPO_URL:?REPO_URL is required}"
BRANCH="${BRANCH:-main}"
APP_DIR="${APP_DIR:-/opt/app}"
APP_USER="${APP_USER:-${SUDO_USER:-root}}"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

[[ $EUID -eq 0 ]] || exec sudo -E "$0" "$@"

# --- Docker -----------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker Engine"
  . /etc/os-release
  case "$ID" in ubuntu | debian) ;; *) echo "Unsupported distro: $ID" >&2; exit 1 ;; esac

  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl git gnupg

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/$ID/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/$ID ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
fi

# Default json-file driver has no rotation -> logs eventually fill the disk.
if [[ ! -f /etc/docker/daemon.json ]]; then
  cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
JSON
fi

systemctl enable --now docker
[[ "$APP_USER" == root ]] || usermod -aG docker "$APP_USER"

# --- Clone / update ---------------------------------------------------------
as_user() { sudo -u "$APP_USER" -H env GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" "$@"; }

mkdir -p "$APP_DIR"
chown "$APP_USER": "$APP_DIR"

if [[ -d "$APP_DIR/.git" ]]; then
  log "Updating $APP_DIR ($BRANCH)"
  as_user git -C "$APP_DIR" fetch --prune origin "$BRANCH"
  as_user git -C "$APP_DIR" checkout "$BRANCH"
  as_user git -C "$APP_DIR" merge --ff-only "origin/$BRANCH"
else
  log "Cloning $REPO_URL"
  as_user git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
fi

# --- Env guard --------------------------------------------------------------
if [[ -f "$APP_DIR/.env.example" && ! -f "$APP_DIR/.env" ]]; then
  as_user cp "$APP_DIR/.env.example" "$APP_DIR/.env"
  chmod 600 "$APP_DIR/.env"
  echo "Created $APP_DIR/.env from .env.example. Fill in secrets, then re-run." >&2
  exit 1
fi

# --- Up ---------------------------------------------------------------------
log "docker compose up"
cd "$APP_DIR"
as_user docker compose up -d --build --remove-orphans --wait

as_user docker compose ps
