#!/bin/bash

if [ -z "$RCON_PASSWORD" ]; then
  echo "Missing RCON_PASSWORD"
  exit 1
fi

timeout 5 rcon-cli --host=localhost --port=${RCON_PORT:-25575} --password="$RCON_PASSWORD" list > /dev/null

if [ $? -ne 0 ]; then
  echo "RCON healthcheck failed"
  exit 1
fi

echo "RCON is healthy"
exit 0
