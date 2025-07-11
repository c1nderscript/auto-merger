#!/bin/bash
set -euo pipefail

# Setup script for environment variables
# This script sets up the required environment variables for the auto-merge system

ENV_FILE="/opt/scripts/auto-merge.env"

# Ensure environment file exists
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: Environment file $ENV_FILE not found." >&2
    echo "Create the file with GITHUB_TOKEN and GITHUB_USERNAME variables." >&2
    exit 1
fi

echo "Loading environment variables from $ENV_FILE"
# shellcheck source=/opt/scripts/auto-merge.env
source "$ENV_FILE"

# Validate required variables
: "${GITHUB_TOKEN:?Error: GITHUB_TOKEN is not set or empty in $ENV_FILE}"
: "${GITHUB_USERNAME:?Error: GITHUB_USERNAME is not set or empty in $ENV_FILE}"

export GITHUB_TOKEN GITHUB_USERNAME

echo "Environment variables set successfully:"
echo "  GITHUB_USERNAME: $GITHUB_USERNAME"
echo "  GITHUB_TOKEN: [REDACTED]"

# Run the command passed as arguments
if [ "$#" -gt 0 ]; then
    echo "Executing: $*"
    exec "$@"
fi
