#!/bin/bash
set -euo pipefail

# GitHub App Authentication Script
# Generates JWT, exchanges for installation token

# Configuration
CLIENT_ID="Iv23liEdil5KNk2fcxh3"  # Using Client ID instead of App ID
PRIVATE_KEY_PATH="/root/automerge/github-app-private-key.pem"
GITHUB_USERNAME="c1nderscript"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Base64 encode function for JWT
b64enc() { 
    openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'
}

# Function to generate JWT using GitHub's recommended approach
generate_jwt() {
    local client_id="$1"
    local private_key_path="$2"
    
    # Get current time
    local now=$(date +%s)
    local iat=$((now - 60))    # Issues 60 seconds in the past (for clock drift)
    local exp=$((now + 600))   # Expires 10 minutes in the future
    
    # Read private key
    local pem=$(cat "$private_key_path")
    
    # JWT Header
    local header_json='{
        "typ":"JWT",
        "alg":"RS256"
    }'
    local header=$(echo -n "$header_json" | b64enc)
    
    # JWT Payload
    local payload_json="{
        \"iat\":${iat},
        \"exp\":${exp},
        \"iss\":\"${client_id}\"
    }"
    local payload=$(echo -n "$payload_json" | b64enc)
    
    # Create signature
    local header_payload="${header}.${payload}"
    local signature=$(
        openssl dgst -sha256 -sign <(echo -n "${pem}") \
        <(echo -n "${header_payload}") | b64enc
    )
    
    # Complete JWT
    echo "${header_payload}.${signature}"
}

# Function to get installation ID for a user
get_installation_id() {
    local jwt="$1"
    local username="$2"
    
    local response=$(curl -s -H "Authorization: Bearer $jwt" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/users/$username/installation")
    
    if echo "$response" | jq -e .id > /dev/null 2>&1; then
        echo "$response" | jq -r .id
    else
        log "Error getting installation ID: $response"
        return 1
    fi
}

# Function to get installation access token
get_installation_token() {
    local jwt="$1"
    local installation_id="$2"
    
    local response=$(curl -s -X POST \
        -H "Authorization: Bearer $jwt" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/app/installations/$installation_id/access_tokens")
    
    if echo "$response" | jq -e .token > /dev/null 2>&1; then
        echo "$response" | jq -r .token
    else
        log "Error getting installation token: $response"
        return 1
    fi
}

# Main authentication function
authenticate() {
    log "Starting GitHub App authentication..."
    
    # Check if private key exists
    if [ ! -f "$PRIVATE_KEY_PATH" ]; then
        log "Error: Private key not found at $PRIVATE_KEY_PATH"
        return 1
    fi
    
    # Generate JWT
    log "Generating JWT with Client ID: $CLIENT_ID"
    local jwt=$(generate_jwt "$CLIENT_ID" "$PRIVATE_KEY_PATH")
    
    if [ -z "$jwt" ]; then
        log "Error: Failed to generate JWT"
        return 1
    fi
    
    log "JWT generated successfully"
    
    # Test JWT by calling /app endpoint
    log "Testing JWT with /app endpoint..."
    local app_response=$(curl -s -H "Authorization: Bearer $jwt" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/app")
    
    if echo "$app_response" | jq -e .name > /dev/null 2>&1; then
        local app_name=$(echo "$app_response" | jq -r .name)
        log "JWT test successful. App name: $app_name"
    else
        log "JWT test failed: $app_response"
        return 1
    fi
    
    # Get installation ID
    log "Getting installation ID for user: $GITHUB_USERNAME"
    local installation_id=$(get_installation_id "$jwt" "$GITHUB_USERNAME")
    
    if [ -z "$installation_id" ]; then
        log "Error: Failed to get installation ID"
        return 1
    fi
    
    log "Installation ID: $installation_id"
    
    # Get installation access token
    log "Getting installation access token..."
    local access_token=$(get_installation_token "$jwt" "$installation_id")
    
    if [ -z "$access_token" ]; then
        log "Error: Failed to get installation access token"
        return 1
    fi
    
    log "Successfully obtained installation access token"
    
    # Export the token
    export GITHUB_APP_TOKEN="$access_token"
    export GITHUB_INSTALLATION_ID="$installation_id"
    
    # Save to file for other scripts to use
    echo "export GITHUB_APP_TOKEN=\"$access_token\"" > /tmp/github-app-token.env
    echo "export GITHUB_INSTALLATION_ID=\"$installation_id\"" >> /tmp/github-app-token.env
    echo "export GITHUB_TOKEN=\"$access_token\"" >> /tmp/github-app-token.env  # For compatibility
    chmod 600 /tmp/github-app-token.env
    
    log "Token saved to /tmp/github-app-token.env"
    
    # Test the installation token
    log "Testing installation access token..."
    local test_response=$(curl -s -H "Authorization: token $access_token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/app/installations/$installation_id")
    
    if echo "$test_response" | jq -e .id > /dev/null 2>&1; then
        local app_slug=$(echo "$test_response" | jq -r .app_slug)
        local account=$(echo "$test_response" | jq -r .account.login)
        log "Installation token test successful. App: $app_slug, Account: $account"
        
        # Test repository access
        log "Testing repository access..."
        local repos_response=$(curl -s -H "Authorization: token $access_token" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/installation/repositories?per_page=5")
        
        if echo "$repos_response" | jq -e .repositories > /dev/null 2>&1; then
            local repo_count=$(echo "$repos_response" | jq -r '.total_count')
            log "Repository access test successful. Accessible repositories: $repo_count"
            
            # Show first few repositories
            if [ "$repo_count" -gt 0 ]; then
                log "Sample repositories:"
                echo "$repos_response" | jq -r '.repositories[0:3][] | "  - " + .full_name'
            fi
        else
            log "Repository access test failed: $repos_response"
        fi
    else
        log "Installation token test failed: $test_response"
        return 1
    fi
    
    log "GitHub App authentication completed successfully!"
    return 0
}

# If script is run directly, execute authentication
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    authenticate
fi
