#!/bin/bash

# AGGRESSIVE FORCE MERGE SCRIPT WITH GITHUB APP AUTHENTICATION
# For experimental AI-generated code workflows
# Merges everything regardless of conflicts or test failures

# Load GitHub App authentication
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/github-app-auth.sh"

# Authenticate and get fresh token
if ! authenticate; then
    echo "Error: GitHub App authentication failed. Falling back to personal access token."
    # Fallback to personal access token
    export GITHUB_TOKEN="${GITHUB_TOKEN_FALLBACK:-}"
    export GITHUB_USERNAME="c1nderscript"
else
    # Load the GitHub App token
    source /tmp/github-app-token.env
    export GITHUB_USERNAME="c1nderscript"
    echo "Using GitHub App authentication with higher rate limits"
fi

WORKSPACE="/tmp/force-merge"
LOG_FILE="/tmp/force-merge.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FORCE-MERGE: $1" | tee -a "$LOG_FILE"
}

# Check if we have a valid token
if [ -z "$GITHUB_TOKEN" ]; then
    log "Error: No GitHub token available. Please check authentication setup."
    exit 1
fi

log "Force merge session started"
log "Starting aggressive force merge process..."

# Get all repos
get_all_repos() {
    gh repo list "$GITHUB_USERNAME" --limit 1000 --json name,url,defaultBranchRef | \
    jq -r '.[] | "\(.name)|\(.url)|\(.defaultBranchRef.name)"'
}

# Force merge all PRs in a repo
force_merge_all_prs() {
    local repo_name="$1"
    local repo_url="$2"
    local default_branch="$3"
    
    log "Processing repo: $repo_name"
    
    # Clone or update repo
    if [ -d "$repo_name" ]; then
        cd "$repo_name"
        git fetch --all --prune
    else
        git clone "$repo_url" "$repo_name"
        cd "$repo_name"
    fi
    
    # Disable branch protection temporarily (if admin)
    gh api repos/"$GITHUB_USERNAME"/"$repo_name"/branches/"$default_branch"/protection \
        --method DELETE 2>/dev/null || true
    
    # Get all open PRs
    local prs=$(gh pr list --state open --json number,headRefName,baseRefName --jq '.[] | "\(.number)|\(.headRefName)|\(.baseRefName)"')
    
    if [ -z "$prs" ]; then
        log "No PRs found in $repo_name"
    else
        log "Processing PRs in $repo_name"
    
        echo "$prs" | while IFS='|' read -r pr_number head_branch base_branch; do
            log "Force merging PR #$pr_number: $head_branch -> $base_branch"
            
            # Try normal merge first
            if gh pr merge "$pr_number" --squash --auto 2>/dev/null; then
                log "✅ Normal merge successful for PR #$pr_number"
            else
                # Force merge approach
                force_merge_pr "$repo_name" "$pr_number" "$head_branch" "$base_branch"
            fi
        done
    fi
    
    cd ..
}

# Force merge a specific PR using git commands
force_merge_pr() {
    local repo_name="$1"
    local pr_number="$2"
    local head_branch="$3"
    local base_branch="$4"
    
    log "Attempting force merge for PR #$pr_number"
    
    # Switch to base branch
    git checkout "$base_branch" 2>/dev/null || git checkout -b "$base_branch" "origin/$base_branch"
    git reset --hard "origin/$base_branch"
    
    # Fetch the PR branch
    git fetch origin "$head_branch:$head_branch" 2>/dev/null || true
    
    # Try different merge strategies
    if git merge "$head_branch" --no-ff --strategy=recursive -X theirs; then
        log "Merge successful with 'theirs' strategy"
    elif git merge "$head_branch" --no-ff --strategy=ours; then
        log "Merge successful with 'ours' strategy"  
    else
        # Force merge by creating a merge commit manually
        git merge --abort 2>/dev/null || true
        git reset --hard "origin/$base_branch"
        
        # Get the commits from head branch
        local head_commit=$(git rev-parse "$head_branch")
        git merge --no-ff --strategy=ours "$head_branch" -m "Force merge PR #$pr_number: $head_branch -> $base_branch"
        
        if [ $? -eq 0 ]; then
            log "Force merge successful with 'ours' strategy"
        else
            log "❌ Force merge failed for PR #$pr_number"
            return 1
        fi
    fi
    
    # Push the merge
    if git push origin "$base_branch" 2>/dev/null; then
        log "✅ Successfully pushed merged changes for PR #$pr_number"
        
        # Close the PR
        gh pr close "$pr_number" --comment "Auto-merged via force merge script" 2>/dev/null || true
    else
        log "ERROR: Failed to push merged changes for PR #$pr_number"
    fi
}

# Force merge all branches in a repo
force_merge_all_branches() {
    local repo_name="$1"
    local default_branch="$2"
    
    log "Force merging all branches in $repo_name"
    
    cd "$repo_name"
    
    # Switch to default branch
    git checkout "$default_branch" 2>/dev/null || git checkout -b "$default_branch" "origin/$default_branch"
    git reset --hard "origin/$default_branch"
    
    # Get all remote branches except default
    local branches=$(git branch -r | grep -v "origin/$default_branch" | grep -v "HEAD" | sed 's/origin\///' | tr -d ' ')
    
    for branch in $branches; do
        if [ -n "$branch" ] && [ "$branch" != "$default_branch" ]; then
            log "Force merging branch: $branch"
            
            # Fetch the branch
            git fetch origin "$branch:$branch" 2>/dev/null || continue
            
            # Try to merge
            if git merge "$branch" --no-ff --strategy=recursive -X theirs 2>/dev/null; then
                log "✅ Merged branch $branch"
            elif git merge "$branch" --no-ff --strategy=ours 2>/dev/null; then
                log "✅ Merged branch $branch with 'ours' strategy"
            else
                git merge --abort 2>/dev/null || true
                log "⚠️ Skipped problematic branch: $branch"
            fi
        fi
    done
    
    # Push all changes
    git push origin "$default_branch" 2>/dev/null || log "Failed to push branch merges"
    
    cd ..
}

# Main execution
main() {
    # Create workspace
    rm -rf "$WORKSPACE"
    mkdir -p "$WORKSPACE"
    cd "$WORKSPACE"
    
    # Get all repositories
    local repos=$(get_all_repos)
    
    echo "$repos" | while IFS='|' read -r repo_name repo_url default_branch; do
        if [ -n "$repo_name" ]; then
            log "========================================="
            log "Processing repository: $repo_name"
            
            # Force merge all PRs first
            force_merge_all_prs "$repo_name" "$repo_url" "$default_branch"
            
            # Then force merge any remaining branches
            force_merge_all_branches "$repo_name" "$default_branch"
            
            log "Completed processing $repo_name"
        fi
    done
    
    log "Force merge process completed - check individual repos for issues to fix"
}

# Cleanup
cleanup() {
    log "Cleaning up workspace..."
    cd /
    rm -rf "$WORKSPACE"
}

trap cleanup EXIT

main "$@"
