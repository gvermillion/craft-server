#!/bin/bash
# -----------------------------------------------------------------------------
# Script Name: logging.sh
# Description: This script provides logging utilities for server operations.
#              It includes functions to log messages with different severity
#              levels (e.g., INFO, ERROR) and to manage log output.
# Usage:       Source this script in other shell scripts to use its logging
#              functions.
# Author:      Grant Vermillion
# -----------------------------------------------------------------------------



# Function: ensure_log_dir
# Description:
#   Ensures that the specified log directory exists. If the directory
#   does not exist, it will be created.
# Parameters:
#   $1 - The path to the directory to create if it doesn't exist.
# Usage:
#   ensure_log_dir "/var/log/my_script"
ensure_log_dir() {
    local log_dir="$1"
    mkdir -p "$log_dir"
}

# Function: setup_logging
# Description:
#   Configures logging by redirecting both standard output (stdout) and
#   standard error (stderr) to a specified log file. The output is also
#   displayed in the terminal in real-time using the `tee` command.
# Parameters:
#   $1 - The path to the log file where logs will be appended.
# Usage:
#   setup_logging "/path/to/logfile.log"
setup_logging() {
    local log_file="$1"
    exec > >(tee -a "$log_file") 2>&1
}

# Function: log
# Description:
#   Logs a message with a timestamp to both the terminal and the configured
#   log file. Useful for standard informational output.
# Parameters:
#   $1 - The message string to log.
# Usage:
#   log "Starting backup..."
log() {
    echo "[$(date)]  INFO: $1"
}

# Function: error
# Description:
#   Logs an error message with a timestamp to stderr and exits the script
#   with a non-zero status code.
# Parameters:
#   $1 - The error message string to log.
# Usage:
#   error "Failed to create backup directory"
error() {
    echo "[$(date)] ERROR: $1" >&2
    exit 1
}

# Function: trap_errors
# Description:
#   Installs a global error handler that logs an error message including
#   the line number where the script failed. This is useful for debugging.
# Usage:
#   trap_errors
trap_errors() {
    trap 'error "Script failed at line $LINENO"' ERR
}

# Function: init_logging
# Description:
#   Initializes the logging system by ensuring the log directory exists,
#   setting up log redirection, and installing the error trap.
# Parameters:
#   $1 - The path to the directory where the log file should be stored.
#   $2 - The path to the log file.
# Usage:
#   init_logging "/var/log/my_script" "/var/log/my_script/run.log"
init_logging() {
    local run_id="$1"
    local script_name="$2"


    if [ "${LOG_ALREADY_INIT:-false}" = true ]; then
        log "Logging is already initialized. Skipping reinitialization."
        return
    fi

    log_dir="/var/log/server/backup/${run_id}"
    log_file="${log_dir}/${script_name%.sh}.log"
    ensure_log_dir "$log_dir"
    setup_logging "$log_file"
    trap_errors
    log "Logging initialized for run ID: ${run_id}"
    LOG_ALREADY_INIT=true
}