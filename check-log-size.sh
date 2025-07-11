#!/bin/bash
set -euo pipefail

# Log Size Monitoring Script for Force-Merge
# Run this script weekly to check log file size

LOG_FILE="/var/log/force-merge.log"
WARNING_SIZE_MB=50
CRITICAL_SIZE_MB=100

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "=== Force-Merge Log Size Monitor ==="
echo "Timestamp: $(date)"
echo

if [ ! -f "$LOG_FILE" ]; then
    echo -e "${YELLOW}WARNING: Log file $LOG_FILE does not exist${NC}"
    exit 1
fi

# Get file size in MB
FILE_SIZE_BYTES=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
FILE_SIZE_MB=$((FILE_SIZE_BYTES / 1024 / 1024))

echo "Log file: $LOG_FILE"
echo "Size: ${FILE_SIZE_MB}MB (${FILE_SIZE_BYTES} bytes)"

# Check disk usage
DISK_USAGE=$(df /var/log | tail -1 | awk '{print $5}' | sed 's/%//')
echo "Disk usage (/var/log): ${DISK_USAGE}%"

# Determine status
if [ "$FILE_SIZE_MB" -ge "$CRITICAL_SIZE_MB" ]; then
    echo -e "${RED}CRITICAL: Log file size exceeds ${CRITICAL_SIZE_MB}MB!${NC}"
    echo "Action required: Rotate log file immediately"
    exit 2
elif [ "$FILE_SIZE_MB" -ge "$WARNING_SIZE_MB" ]; then
    echo -e "${YELLOW}WARNING: Log file size exceeds ${WARNING_SIZE_MB}MB${NC}"
    echo "Action recommended: Plan log rotation"
    exit 1
else
    echo -e "${GREEN}OK: Log file size is within acceptable limits${NC}"
fi

# Show recent log activity
echo
echo "Recent log entries (last 5):"
tail -5 "$LOG_FILE" 2>/dev/null || echo "Cannot read log file"

echo
echo "=== End of Report ==="
