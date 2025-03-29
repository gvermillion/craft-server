#!/bin/bash

# Simple CLI wrapper for CRAFT
# Usage: ./craft.sh [up|down|backup|restore]

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

function teardown_droplet() {
    echo "Tearing down droplet with ID: $droplet_id due to deployment failure..."
    curl -s -X DELETE "https://api.digitalocean.com/v2/droplets/$droplet_id" \
        -H "Authorization: Bearer $DO_API_TOKEN"
}

function up() {
    local world_id="${1:-$WORLD_ID}"
    if [[ -z "$world_id" ]]; then
        echo "Error: WORLD_ID is not set and no world_id argument was provided."
        return 1
    fi
    echo "Starting server with world ID '${world_id}'..."
    export WORLD_ID="$world_id"
    docker-compose up -d
}

function down() {
    docker-compose down
}

function backup() {
    echo "Triggering manual backup (simulated)..."
    docker exec craft-server kill -SIGTERM 1
}

function restore() {
    local world_id="$1"
    if [[ -z "$world_id" ]]; then
        echo "Error: world_id argument is required."
        echo "Usage: restore <world_id>"
        return 1
    fi
    echo "Restoring backup for world ID '${world_id}' from remote..."
    rsync -avz "${RSYNC_USER}@${RSYNC_HOST}:${BACKUP_PATH}/"/latest/ "${DATA_DIR}/"
}

function deploy() {

    local world_id="${1:-$WORLD_ID}"
    if [[ -z "$world_id" ]]; then
        echo "Error: WORLD_ID is not set and no world_id argument was provided."
        return 1
    fi
    echo "Using world ID '${world_id}' for deployment..."
    export WORLD_ID="$world_id"

    if [ -z "$DO_API_TOKEN" ]; then
        echo "DO_API_TOKEN not set. Please set DO_API_TOKEN in your environment or in sample.env."
        exit 1
    fi
    echo "Creating a new DigitalOcean droplet..."
    response=$(curl -s -X POST "https://api.digitalocean.com/v2/droplets" \
        -H "Authorization: Bearer $DO_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "craft-server",
            "region": "sfo3",
            "size": "s-2vcpu-4gb",
            "image": "ubuntu-20-04-x64",
            "ssh_keys": [46448684, "'"${RSYNC_SSH_KEY_ID}"'"],
            "backups": false,
            "ipv6": true,
            "user_data": null,
            "private_networking": null,
            "volumes": null,
            "tags": ["craft"]
        }')
    droplet_id=$(echo "$response" | jq -r '.droplet.id')
    if [ "$droplet_id" == "null" ]; then
        echo "Error creating droplet: $(echo "$response" | jq -r '.message')"
        exit 1
    fi
    echo "Droplet created with ID: $droplet_id"

    echo "Setting teardown trap..."
    trap teardown_droplet ERR

    echo "Waiting for droplet to become active..."
    while true; do
        droplet_status=$(curl -s -X GET "https://api.digitalocean.com/v2/droplets/$droplet_id" \
            -H "Authorization: Bearer $DO_API_TOKEN" \
            -H "Content-Type: application/json" | jq -r '.droplet.status')
        if [ "$droplet_status" == "active" ]; then
            break
        fi
        sleep 5
    done

    droplet_ip=$(curl -s -X GET "https://api.digitalocean.com/v2/droplets/$droplet_id" \
        -H "Authorization: Bearer $DO_API_TOKEN" \
        -H "Content-Type: application/json" | jq -r '.droplet.networks.v4[] | select(.type=="public") | .ip_address')
    if [ -z "$droplet_ip" ]; then
        echo "Failed to retrieve droplet IP address."
        exit 1
    fi
    echo "Droplet is now active with IP: $droplet_ip"

    # Wait for SSH to be available
    echo "Waiting for SSH on droplet to become available..."
    while ! nc -z "$droplet_ip" 22; do
        echo "SSH not available yet, waiting..."
        sleep 10
    done

    echo "Uploading .env file to droplet..."
    if [ -f ".env" ]; then
        scp -i "$DO_SSH_KEY" -o StrictHostKeyChecking=no .env "root@$droplet_ip:.env"
    else
        echo ".env file not found. Please ensure you have a .env file in your project root."
        exit 1
    fi

    echo "Deploying CRAFT (world ID: ${WORLD_ID} to droplet at IP: $droplet_ip"
    if [ -f "deploy.sh" ]; then
        scp -i "$DO_SSH_KEY" deploy.sh "root@$droplet_ip:/tmp/deploy.sh" && \
        ssh -i "$DO_SSH_KEY" "root@$droplet_ip" "mkdir -p /app && cp .env /app/.env" && \
        ssh -i "$DO_SSH_KEY" "root@$droplet_ip" "sudo apt update && sudo apt install -y docker.io docker-compose git curl sed netcat jq uuid-runtime openssh-client && export WORLD_ID_='${WORLD_ID}' && chmod +x /tmp/deploy.sh && /tmp/deploy.sh"
    else
        echo "deploy.sh not found. Please ensure you have a deploy.sh script in your project root."
        exit 1
    fi

    # Clear the trap on successful deployment
    trap - ERR
}

case "$1" in
    up) up ;;
    down) down ;;
    backup) backup ;;
    restore) 
        shift
        restore "$@"
        ;;
    deploy)
        shift
        deploy "$@"
        ;;
    *)
        echo "CRAFT CLI - Usage: $0 {up|down|backup|restore <world_id>|deploy <world_id>}"
        ;;
esac
