#!/bin/bash
set -euo pipefail

# Auto-merge script for all repositories
# This script scans all repos and merges PRs/branches if no conflicts exist

# Configuration
GITHUB_TOKEN="${GITHUB_TOKEN:-}"  # Set your GitHub token as environment variable
GITHUB_USERNAME="${GITHUB_USERNAME:-}"  # Set your GitHub username
# Base directory for all log files
LOG_DIR="${LOG_DIR:-/var/log/auto-merge}"
# Individual log file for this script
LOG_FILE="$LOG_DIR/merge.log"
REPO_DIR="/tmp/auto-merge-repos"
MAX_RETRIES=3
# Parallel settings
PARALLEL=false
PARALLEL_LIMIT=4

# Current repo name for log prefix
CURRENT_REPO=""

# Generic retry helper
retry() {
    local attempt=1
    until "$@"; do
        if [ "$attempt" -ge "$MAX_RETRIES" ]; then
            log "Command failed after $MAX_RETRIES attempts: $*"
            return 1
        fi
        log "Retrying ($attempt/$MAX_RETRIES)..."
        attempt=$((attempt + 1))
        sleep 2
    done
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Automatically check log size unless explicitly skipped
if [ -z "$SKIP_LOG_SIZE_CHECK" ]; then
    ./check-log-size.sh
    rc=$?
    if [ "$rc" -eq 2 ]; then
        echo -e "${RED}Critical log size threshold exceeded. Aborting merge.${NC}"
        exit 1
    fi
fi

# Logging function
log() {
    local prefix=""
    if [ -n "$CURRENT_REPO" ]; then
        prefix="[$CURRENT_REPO] "
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${prefix}$1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Parse command line arguments
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --parallel)
                PARALLEL=true
                if [[ $2 =~ ^[0-9]+$ ]]; then
                    PARALLEL_LIMIT="$2"
                    shift
                fi
                ;;
        esac
        shift
    done
}

# Check prerequisites
check_prerequisites() {
    if [ -z "$GITHUB_TOKEN" ]; then
        error_exit "GITHUB_TOKEN environment variable not set"
    fi
    
    if [ -z "$GITHUB_USERNAME" ]; then
        error_exit "GITHUB_USERNAME environment variable not set"
    fi
    
    if ! command -v gh &> /dev/null; then
        error_exit "GitHub CLI (gh) is not installed. Install it first."
    fi

    if ! command -v git &> /dev/null; then
        error_exit "Git is not installed"
    fi

    if ! command -v jq &> /dev/null; then
        error_exit "jq is not installed"
    fi

    # Authenticate with GitHub CLI
    echo "$GITHUB_TOKEN" | gh auth login --with-token
}

# Get all repositories for the user
get_repositories() {
    log "Fetching all repositories for $GITHUB_USERNAME..."
    gh repo list "$GITHUB_USERNAME" --limit 1000 --json name,url,defaultBranch | jq -r '.[] | "\(.name)|\(.url)|\(.defaultBranch)"'
}

# Clone or update repository
setup_repo() {
    local repo_name="$1"
    local repo_url="$2"
    local repo_path="$REPO_DIR/$repo_name"
    
    if [ -d "$repo_path" ]; then
        log "Updating existing repo: $repo_name"
        cd "$repo_path" || return 1
        git fetch --all --prune
        git reset --hard origin/HEAD
    else
        log "Cloning repo: $repo_name"
        mkdir -p "$REPO_DIR"
        cd "$REPO_DIR" || return 1
        git clone "$repo_url" "$repo_name"
        cd "$repo_name" || return 1
    fi
}

# Check for mergeable pull requests
check_pull_requests() {
    local repo_name="$1"
    local default_branch="$2"
    
    log "Checking pull requests for $repo_name..."
    
    # Get all open PRs that are mergeable
    local prs=$(gh pr list --state open --json number,mergeable,mergeStateStatus,headRefName,baseRefName --jq '.[] | select(.mergeable == "MERGEABLE" and .mergeStateStatus == "CLEAN") | "\(.number)|\(.headRefName)|\(.baseRefName)"')
    
    if [ -z "$prs" ]; then
        log "No mergeable PRs found for $repo_name"
        return 0
    fi
    
    echo "$prs" | while IFS='|' read -r pr_number head_branch base_branch; do
        log "Found mergeable PR #$pr_number: $head_branch -> $base_branch"
        merge_pull_request "$repo_name" "$pr_number" "$head_branch" "$base_branch"
    done
}

# Merge a pull request
merge_pull_request() {
    local repo_name="$1"
    local pr_number="$2"
    local head_branch="$3"
    local base_branch="$4"
    
    log "Attempting to merge PR #$pr_number in $repo_name..."
    
    # Double-check that the PR is still mergeable
    local pr_status=$(gh pr view "$pr_number" --json mergeable,mergeStateStatus --jq '{mergeable: .mergeable, status: .mergeStateStatus}')
    local mergeable=$(echo "$pr_status" | jq -r '.mergeable')
    local status=$(echo "$pr_status" | jq -r '.status')
    
    if [ "$mergeable" != "MERGEABLE" ] || [ "$status" != "CLEAN" ]; then
        log "PR #$pr_number is no longer mergeable (mergeable: $mergeable, status: $status)"
        return 1
    fi
    
    # Try to merge with retries
    if retry gh pr merge "$pr_number" --auto --squash; then
        log "✅ Successfully merged PR #$pr_number in $repo_name"
    else
        log "❌ Failed to merge PR #$pr_number in $repo_name"
        return 1
    fi
}

# Check for branches that can be merged into default branch
check_branches() {
    local repo_name="$1"
    local default_branch="$2"
    
    log "Checking branches for direct merge in $repo_name..."
    
    # Get all remote branches except the default branch
    local branches=$(git branch -r | grep -v "origin/$default_branch" | grep -v "origin/HEAD" | sed 's/origin\///' | xargs || true)
    
    if [ -z "$branches" ]; then
        log "No additional branches found for $repo_name"
        return 0
    fi
    
    for branch in $branches; do
        # Skip if branch has an open PR
        local has_pr=$(gh pr list --head "$branch" --json number --jq 'length')
        if [ "$has_pr" -gt 0 ]; then
            log "Branch $branch has open PR, skipping direct merge"
            continue
        fi
        
        # Check if branch can be merged without conflicts
        if can_merge_branch "$branch" "$default_branch"; then
            merge_branch "$repo_name" "$branch" "$default_branch"
        fi
    done
}

# Check if a branch can be merged without conflicts
can_merge_branch() {
    local branch="$1"
    local target="$2"
    
    # Create a temporary merge to test for conflicts
    git checkout "$target" >/dev/null 2>&1
    git reset --hard "origin/$target" >/dev/null 2>&1
    
    # Try merge with no-commit to test
    if git merge --no-commit --no-ff "origin/$branch" >/dev/null 2>&1; then
        git merge --abort >/dev/null 2>&1
        return 0
    else
        git merge --abort >/dev/null 2>&1
        return 1
    fi
}

# Merge a branch directly
merge_branch() {
    local repo_name="$1"
    local branch="$2"
    local target="$3"
    
    log "Attempting to merge branch $branch into $target in $repo_name..."
    
    git checkout "$target"
    git reset --hard "origin/$target"
    
    if git merge --no-ff "origin/$branch"; then
        if retry git push origin "$target"; then
            log "✅ Successfully merged branch $branch into $target in $repo_name"
            # Optionally delete the merged branch
            # git push origin --delete "$branch"
        else
            log "❌ Failed to push merged changes for $repo_name"
            git reset --hard "origin/$target"
        fi
    else
        log "❌ Failed to merge branch $branch in $repo_name"
        git merge --abort
    fi
}

# Process a single repository
process_repository() {
    local repo_info="$1"
    IFS='|' read -r repo_name repo_url default_branch <<< "$repo_info"

    CURRENT_REPO="$repo_name"

    log "Processing repository: $repo_name"
    
    if setup_repo "$repo_name" "$repo_url"; then
        # Check for mergeable pull requests first
        check_pull_requests "$repo_name" "$default_branch"
        
        # Then check for branches that can be merged directly
        check_branches "$repo_name" "$default_branch"
    else
        log "❌ Failed to setup repository $repo_name"
    fi
    CURRENT_REPO=""
}

# Main execution
main() {
    parse_args "$@"
    log "Starting auto-merge process..." 
    
    check_prerequisites
    
    # Create working directory
    mkdir -p "$REPO_DIR"
    
    # Get all repositories and process them
    local repos=$(get_repositories)
    
    if [ -z "$repos" ]; then
        log "No repositories found"
        exit 0
    fi
    
    IFS=$'\n'
    if [ "$PARALLEL" = true ]; then
        local pids=()
        for repo_info in $repos; do
            [ -z "$repo_info" ] && continue
            process_repository "$repo_info" &
            pids+=("$!")
            if [ "${#pids[@]}" -ge "$PARALLEL_LIMIT" ]; then
                wait -n
                pids=( $(jobs -pr) )
            fi
        done
        wait
    else
        for repo_info in $repos; do
            [ -z "$repo_info" ] && continue
            process_repository "$repo_info"
        done
    fi
    
    log "Auto-merge process completed"
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    # Remove the temporary repository directory if it exists
    if [ -d "$REPO_DIR" ]; then
        rm -rf "$REPO_DIR"
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"
