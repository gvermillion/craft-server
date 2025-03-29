#!/bin/bash

set -e

if [ -f ".env" ]; then
    ENV_FILE=".env"
elif [ -f "/app/.env" ]; then
    ENV_FILE="/app/.env"
else
    echo "Error: .env file not found in the current directory or /root."
    exit 1
fi

echo "Using .env file: $ENV_FILE"
source "$ENV_FILE"

WORLD_ID="${1:-$WORLD_ID_}"
if [ -z "$WORLD_ID" ]; then
  echo "No WORLD_ID provided, generating a new one..."
  UUID_HASH=$(uuidgen | sha1sum | awk '{print $1}')
  WORLD_ID="world_id_${UUID_HASH:0:8}"
fi

: "${RSYNC_HOST:?Must set RSYNC_HOST}"
: "${RSYNC_PATH:?Must set RSYNC_PATH}"
: "${RSYNC_USER:?Must set RSYNC_USER}"
: "${RCON_PASSWORD:?Must set RCON_PASSWORD}"
: "${WORLD_ID:="craft_world_$(cat /proc/sys/kernel/random/uuid | cut -d'-' -f1)"}"
: "${DATA_DIR:="/craft_data"}"

mkdir -p "${DATA_DIR}"

BACKUP_TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
WORLD_BACKUP_PATH="${RSYNC_PATH}/${WORLD_ID}"
BACKUP_PATH="${WORLD_BACKUP_PATH}/${BACKUP_TIMESTAMP}"

echo "==> Attempting to download latest backup from rsync..."
if rsync -az --delete "ssh -o StrictHostKeyChecking=no" "${RSYNC_USER}@${RSYNC_HOST}:${WORLD_BACKUP_PATH}/latest/" "${DATA_DIR}/"; then
  echo "==> Successfully restored world '${WORLD_ID}'"
else
  echo "==> No existing backup found for '${WORLD_ID}'. Initializing new world..."
  mkdir -p "${DATA_DIR}/world"
fi

mkdir -p "${DATA_DIR}/plugins"

if [ ! -f "${DATA_DIR}/plugins/Geyser-Spigot.jar" ]; then
  echo "==> Downloading Geyser..."
  curl -sLo "${DATA_DIR}/plugins/Geyser-Spigot.jar" https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot
fi

if [ ! -f "${DATA_DIR}/plugins/floodgate-spigot.jar" ]; then
  echo "==> Downloading Floodgate..."
  curl -sLo "${DATA_DIR}/plugins/floodgate-spigot.jar" https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot
fi

echo "==> Starting Minecraft server..."
/start &
MC_PID=$!

trap 'handle_exit' SIGTERM SIGINT

handle_exit() {
  echo "==> Stopping Minecraft..."
  kill $MC_PID
  wait $MC_PID

  echo "==> Backing up world '${WORLD_ID}' to ${BACKUP_PATH}..."
  rsync -az --delete "${DATA_DIR}/" "${RSYNC_USER}@${RSYNC_HOST}:${BACKUP_PATH}/"

  echo "==> Updating latest symlink for '${WORLD_ID}'..."
  ssh ${RSYNC_USER}@${RSYNC_HOST} <<EOF
    mkdir -p ${WORLD_BACKUP_PATH}
    cd ${WORLD_BACKUP_PATH}
    rm -f latest
    ln -s ${BACKUP_TIMESTAMP} latest
EOF

  exit
}

wait $MC_PID
