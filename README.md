# Containerized Minecraft Java + Bedrock Server

```ascii
 .----------------. .----------------. .----------------. .----------------. .----------------. 
| .--------------. | .--------------. | .--------------. | .--------------. | .--------------. |
| |     ______   | | |  _______     | | |      __      | | |  _________   | | |  _________   | |
| |   .' ___  |  | | | |_   __ \    | | |     /  \     | | | |_   ___  |  | | | |  _   _  |  | |
| |  / .'   \_|  | | |   | |__) |   | | |    / /\ \    | | |   | |_  \_|  | | | |_/ | | \_|  | |
| |  | |         | | |   |  __ /    | | |   / ____ \   | | |   |  _|      | | |     | |      | |
| |  \ `.___.'\  | | |  _| |  \ \_  | | | _/ /    \ \_ | | |  _| |_       | | |    _| |_     | |
| |   `._____.'  | | | |____| |___| | | ||____|  |____|| | | |_____|      | | |   |_____|    | |
| |              | | |              | | |              | | |              | | |              | |
| '--------------' | '--------------' | '--------------' | '--------------' | '--------------' |
 '----------------' '----------------' '----------------' '----------------' '----------------' 
```                                  
**C**ontainerized **R**sync-backed **A**ccessible **F**lexible **T**errain

## Overview

This project sets up a Paper Minecraft server with:
- Crossplay via GeyserMC (Switch, Xbox, etc.)
- Floodgate support for Bedrock players
- Rsync-based versioned world backups
- Health checks via RCON
- Auto-initialization of worlds per `WORLD_ID`

## Usage

1. Set environment variables in `craft.sh`:
   - `RSYNC_HOST`, `RSYNC_PATH`, `RSYNC_USER`
   - `WORLD_ID` (used to namespace backups)
   - `RCON_PASSWORD`

2. Build and run:

```bash
./craft.sh build
./craft.sh up
```

3. Tear down and backup happens automatically on container shutdown.

4. To manually tear down the server:

```bash
./craft.sh down
```

## Manual Restore

To manually restore a world backup:

1. Locate the desired backup on your remote storage.
2. Download the backup using `rsync`:

```bash
rsync -avz [RSYNC_USER]@[RSYNC_HOST]:[RSYNC_PATH]/[WORLD_ID]/[BACKUP_NAME] ./world
```

3. Replace the current `world` directory in the server's data folder with the downloaded backup:

```bash
rm -rf ./data/world
mv ./world ./data/world
```

4. Start the server:

```bash
./craft.sh up
```

## Requirements

- Remote rsync/ssh storage
- Docker + Compose
