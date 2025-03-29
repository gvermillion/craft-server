#!/bin/bash
set -e

echo "Starting deploy script..."

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

echo "Debugging environment variables from $ENV_FILE:"
while IFS='=' read -r key value; do
  if [[ ! -z "$key" && "$key" != \#* ]]; then
    echo "$key=$value"
  fi
done < "$ENV_FILE"

WORLD_ID="${1:-$WORLD_ID_}"
if [ -z "$WORLD_ID" ]; then
  echo "No WORLD_ID provided, generating a new one..."
  UUID_HASH=$(uuidgen | sha1sum | awk '{print $1}')
  WORLD_ID="world_id_${UUID_HASH:0:8}"
fi
echo "Using WORLD_ID: $WORLD_ID"

# Clone repo if it doesn't exist, otherwise update it
if [ ! -d "$PROJECT_DIR" ]; then
  echo "Project directory $PROJECT_DIR does not exist. Cloning repository..."
  git clone "$REPO_URL" "$PROJECT_DIR"
else
  echo "Project directory $PROJECT_DIR exists. Pulling latest changes..."
  cd "$PROJECT_DIR"
  git pull
fi
# Check if .env exists in PROJECT_DIR, if not copy from /app/.env
if [ ! -f "$PROJECT_DIR/.env" ]; then
  echo ".env file not found in $PROJECT_DIR. Copying from /app/.env..."
  cp /app/.env "$PROJECT_DIR/.env"
else
  echo ".env file already exists in $PROJECT_DIR."
fi

cd "$PROJECT_DIR"
echo "Changed directory to $PROJECT_DIR"

# Update the systemd service file with the current project path
SERVICE_FILE="systemd/craft.service"
echo "Updating systemd service file $SERVICE_FILE with current project path..."
sudo sed -i "s|/path/to/craft-server|$(pwd)|g" "$SERVICE_FILE"

# Copy the service file to systemd's directory
echo "Copying $SERVICE_FILE to /etc/systemd/system/craft.service..."
sudo cp "$SERVICE_FILE" /etc/systemd/system/craft.service

# Add a trap to display the status of the service on script exit
trap 'echo "Displaying service status..."; sudo systemctl status craft' EXIT

# Reload systemd and enable/start the service
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload
echo "Enabling craft service..."
sudo systemctl enable craft
echo "Starting craft service..."
sudo systemctl start craft

# Clear the trap to avoid displaying the service status on script exit
trap - EXIT

echo "CRAFT server is now deployed and running."