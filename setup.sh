#!/usr/bin/env bash
# Setup script for the download stack (SABnzbd, Radarr, Sonarr, Prowlarr,
# plus Uptime Kuma and Dozzle for monitoring).
#
# Usage: ./setup.sh [--no-start | --update]
#   --no-start   prepare .env, folders and config, but don't start the containers
#   --update     pull the latest images, recreate changed containers, prune old images

set -euo pipefail

cd "$(dirname "$0")"

MODE=start
for arg in "$@"; do
  case "$arg" in
    --no-start) MODE=prepare ;;
    --update)   MODE=update ;;
    -h|--help)  sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*"; }
fail() { printf '\033[1;31mxx\033[0m  %s\n' "$*" >&2; exit 1; }

# Replace KEY=value in .env (portable across macOS/BSD and GNU sed)
set_env() {
  local key=$1 value=$2 tmp
  tmp=$(mktemp)
  sed "s|^${key}=.*|${key}=${value}|" .env > "$tmp" && mv "$tmp" .env
}

# Append keys from .env.example that are missing in .env (e.g. after an update
# that added a new service)
sync_env() {
  local line key added=0
  while IFS= read -r line; do
    [[ "$line" =~ ^([A-Z0-9_]+)= ]] || continue
    key=${BASH_REMATCH[1]}
    if ! grep -q "^${key}=" .env; then
      [[ $added -eq 0 ]] && printf '\n# Added by setup.sh from .env.example\n' >> .env
      echo "$line" >> .env
      info "Added missing ${key} to .env"
      added=1
    fi
  done < .env.example
}

print_urls() {
  cat <<EOF

Stack is running:
  SABnzbd   http://localhost:${SABNZBD_PORT}
  Radarr    http://localhost:${RADARR_PORT}
  Sonarr    http://localhost:${SONARR_PORT}
  Prowlarr  http://localhost:${PROWLARR_PORT}

Monitoring:
  Uptime Kuma  http://localhost:${UPTIME_KUMA_PORT}
  Dozzle       http://localhost:${DOZZLE_PORT}
EOF
}

# --- Prerequisites -------------------------------------------------
info "Checking prerequisites"
command -v docker >/dev/null 2>&1 \
  || fail "Docker not found. Install Docker Desktop or OrbStack first (see README.md)."
docker compose version >/dev/null 2>&1 \
  || fail "Docker Compose v2 not found ('docker compose'). Update Docker."
docker info >/dev/null 2>&1 \
  || fail "Docker daemon isn't running. Start Docker Desktop/OrbStack and retry."
[[ -f docker-compose.yml ]] || fail "docker-compose.yml not found in $(pwd)"
[[ -f .env.example ]] || fail ".env.example not found in $(pwd)"

# --- .env ----------------------------------------------------------
if [[ ! -f .env ]]; then
  cp .env.example .env
  info "Created .env from .env.example"
else
  sync_env
fi

# --- Update --------------------------------------------------------
if [[ "$MODE" == update ]]; then
  # shellcheck disable=SC1091
  source .env
  mkdir -p "${CONFIG_ROOT}/prowlarr" "${CONFIG_ROOT}/uptime-kuma"
  docker compose config --quiet || fail "Compose file is invalid"
  info "Pulling latest images"
  docker compose pull
  info "Recreating containers with new images"
  docker compose up -d --remove-orphans
  info "Removing old images"
  docker image prune -f
  print_urls
  exit 0
fi

# --- User/group IDs ------------------------------------------------
# shellcheck disable=SC1091
source .env

CUR_UID=$(id -u)
CUR_GID=$(id -g)
if [[ "${PUID:-}" != "$CUR_UID" || "${PGID:-}" != "$CUR_GID" ]]; then
  warn ".env has PUID=${PUID:-unset} PGID=${PGID:-unset}, current user is ${CUR_UID}:${CUR_GID}"
  read -r -p "    Update .env to match the current user? [Y/n] " answer
  if [[ ! "$answer" =~ ^[Nn] ]]; then
    set_env PUID "$CUR_UID"
    set_env PGID "$CUR_GID"
    info "Updated PUID/PGID in .env"
  fi
fi

# Reload in case values changed
# shellcheck disable=SC1091
source .env

# --- Folders -------------------------------------------------------
info "Creating folders under ${CONFIG_ROOT} and ${DATA_ROOT}"
mkdir -p \
  "${CONFIG_ROOT}/sabnzbd" "${CONFIG_ROOT}/radarr" "${CONFIG_ROOT}/sonarr" \
  "${CONFIG_ROOT}/prowlarr" "${CONFIG_ROOT}/uptime-kuma" \
  "${DATA_ROOT}/usenet/incomplete" "${DATA_ROOT}/usenet/complete" \
  "${DATA_ROOT}/media/movies" "${DATA_ROOT}/media/tv"

# --- Validate ------------------------------------------------------
info "Validating docker-compose.yml"
docker compose config --quiet || fail "Compose file is invalid"

# --- Start ---------------------------------------------------------
if [[ "$MODE" == prepare ]]; then
  info "Setup done. Start the stack with: docker compose up -d"
  exit 0
fi

info "Pulling images"
docker compose pull

info "Starting containers"
docker compose up -d

print_urls
echo
echo "Next: follow \"First-time configuration\" in README.md."
