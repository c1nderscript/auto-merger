#!/bin/bash
set -euo pipefail

# Auto-merge Update Script
# Pulls latest changes from auto-merger repo and resets the cronjob

REPO_DIR="/root/automerge"
# Base directory for all log files
LOG_DIR="${LOG_DIR:-/var/log/auto-merge}"
LOG_FILE="$LOG_DIR/automerge-update.log"
GITHUB_USERNAME="c1nderscript"
# GitHub App authentication will be handled by aggro.sh

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUTOMERGE-UPDATE: $1" | tee -a "$LOG_FILE"
}

log "Starting automerge update process..."

# Change to repo directory
cd "$REPO_DIR" || {
    log "ERROR: Cannot change to directory $REPO_DIR"
    exit 1
}

# Pull latest changes
log "Pulling latest changes from auto-merger repository..."
if git pull origin main 2>&1 | tee -a "$LOG_FILE"; then
    log "Successfully pulled latest changes"
else
    log "WARNING: Git pull failed, continuing with existing version"
fi

# Make sure scripts are executable
chmod +x aggro.sh check-log-size.sh setup-env.sh 2>/dev/null || true

# Backup current crontab
crontab -l > /tmp/crontab_backup_$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# Remove existing automerge cronjob (if any)
crontab -l 2>/dev/null | grep -v "aggro.sh" > /tmp/new_crontab_temp || true

# Add the updated automerge cronjob (every minute)
echo "* * * * * cd $REPO_DIR && GITHUB_TOKEN=\"$GITHUB_TOKEN_VALUE\" GITHUB_USERNAME=\"$GITHUB_USERNAME\" ./aggro.sh >> $LOG_DIR/force-merge.log 2>&1" >> /tmp/new_crontab_temp

# Install the new crontab
if crontab /tmp/new_crontab_temp; then
    log "Successfully updated crontab with latest automerge configuration"
else
    log "ERROR: Failed to update crontab"
    exit 1
fi

# Clean up temp file
rm -f /tmp/new_crontab_temp

# Verify the cron job is set correctly
CRON_CHECK=$(crontab -l 2>/dev/null | grep "aggro.sh" || true)
if [ -n "$CRON_CHECK" ]; then
    log "Verification successful: Automerge cron job is active"
    log "Current job: $CRON_CHECK"
else
    log "ERROR: Automerge cron job not found after update"
    exit 1
fi

log "Automerge update process completed successfully"
