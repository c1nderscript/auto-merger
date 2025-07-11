#!/bin/bash

# Automatic log rotation when force-merge log exceeds threshold

LOG_FILE="/var/log/force-merge.log"
CONFIG_FILE="/etc/logrotate.d/force-merge"
THRESHOLD_MB=100

if [ ! -f "$LOG_FILE" ]; then
    echo "Log file $LOG_FILE does not exist" >&2
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Logrotate config $CONFIG_FILE not found" >&2
    exit 1
fi

SIZE_BYTES=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
SIZE_MB=$((SIZE_BYTES / 1024 / 1024))

if [ "$SIZE_MB" -ge "$THRESHOLD_MB" ]; then
    echo "Rotating log: size ${SIZE_MB}MB exceeds ${THRESHOLD_MB}MB"
    sudo logrotate -f "$CONFIG_FILE"
else
    echo "Log size ${SIZE_MB}MB below threshold"
fi

