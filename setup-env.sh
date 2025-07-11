#!/bin/bash
set -euo pipefail

# Setup script for environment variables
# This script sets up the required environment variables for the auto-merge system

# Check if auto-merge.env exists
if [ -f "/opt/scripts/auto-merge.env" ]; then
    echo "Loading environment variables from /opt/scripts/auto-merge.env"
    source /opt/scripts/auto-merge.env
else
    echo "Warning: /opt/scripts/auto-merge.env not found"
fi

# Export required variables
export GITHUB_TOKEN="${GITHUB_TOKEN}"
export GITHUB_USERNAME="${GITHUB_USERNAME}"

# Check if variables are set
if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_USERNAME" ]; then
    echo "Error: Required environment variables are not set"
    echo "Please ensure GITHUB_TOKEN and GITHUB_USERNAME are defined in /opt/scripts/auto-merge.env"
    exit 1
fi

echo "Environment variables set successfully:"
echo "  GITHUB_USERNAME: $GITHUB_USERNAME"
echo "  GITHUB_TOKEN: [REDACTED]"

# Run the command passed as arguments
if [ $# -gt 0 ]; then
    echo "Executing: $*"
    exec "$@"
fi
