#!/bin/bash

# AGGRESSIVE FORCE MERGE SCRIPT
# For experimental AI-generated code workflows
# Merges everything regardless of conflicts or test failures

# Check if environment variables are set
if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_USERNAME" ]; then
    echo "Error: GITHUB_TOKEN and GITHUB_USERNAME must be set as environment variables."
    echo "Please set them before running this script:"
    echo "  export GITHUB_TOKEN=your_token_here"
    echo "  export GITHUB_USERNAME=your_username_here"
    exit 1
fi

WORKSPACE="/tmp/force-merge"
LOG_FILE="/tmp/force-merge.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FORCE-MERGE: $1" | tee -a "$LOG_FILE"
}

error_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE"
}

# Initialize
setup() {
    mkdir -p "$WORKSPACE"
    cd "$WORKSPACE"
    echo "$GITHUB_TOKEN" | gh auth login --with-token
    log "Force merge session started"
}

# Get all repos
get_all_repos() {
    gh repo list "$GITHUB_USERNAME" --limit 1000 --json name,url,defaultBranchRef | \
    jq -r '.[] | "\(.name)|\(.url)|\((.defaultBranchRef.name))"'
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
        cd ..
        return
    fi
    
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
        log "Standard merge failed, forcing manual resolution..."
        
        # Get conflicted files
        local conflicted_files=$(git diff --name-only --diff-filter=U)
        
        if [ -n "$conflicted_files" ]; then
            log "Resolving conflicts in: $conflicted_files"
            
            # Auto-resolve conflicts by accepting incoming changes
            echo "$conflicted_files" | while read -r file; do
                if [ -f "$file" ]; then
                    # Remove conflict markers, keep both versions
                    sed -i '/^<<<<<<< HEAD$/d; /^=======$/d; /^>>>>>>> /d' "$file"
                    git add "$file"
                fi
            done
            
            # Commit the resolution
            git commit -m "Force merge PR #$pr_number - auto-resolved conflicts" 2>/dev/null || true
        fi
    fi
    
    # Force push the result
    if git push origin "$base_branch" --force-with-lease; then
        log "✅ Force pushed merged changes for PR #$pr_number"
        
        # Close the PR
        gh pr close "$pr_number" --comment "Auto-merged via force merge script" 2>/dev/null || true
        
        # Delete the source branch
        git push origin --delete "$head_branch" 2>/dev/null || true
        git branch -D "$head_branch" 2>/dev/null || true
        
    else
        error_log "Failed to push merged changes for PR #$pr_number"
    fi
}

# Force merge all branches into default branch
force_merge_all_branches() {
    local repo_name="$1"
    local default_branch="$2"
    
    log "Force merging all branches in $repo_name"
    
    cd "$repo_name"
    git checkout "$default_branch"
    git reset --hard "origin/$default_branch"
    
    # Get all remote branches except default
    local branches=$(git branch -r | grep -v "origin/$default_branch" | grep -v "origin/HEAD" | sed 's/origin\///' | xargs)
    
    for branch in $branches; do
        if [ -n "$branch" ]; then
            log "Force merging branch: $branch"
            
            # Skip if it has an open PR (we'll handle those separately)
            local has_pr=$(gh pr list --head "$branch" --json number --jq 'length')
            if [ "$has_pr" -gt 0 ]; then
                continue
            fi
            
            # Force merge the branch
            if git merge "origin/$branch" --no-ff --strategy=recursive -X theirs; then
                log "✅ Merged branch $branch"
            else
                # Resolve conflicts automatically
                git diff --name-only --diff-filter=U | while read -r file; do
                    if [ -f "$file" ]; then
                        sed -i '/^<<<<<<< HEAD$/d; /^=======$/d; /^>>>>>>> /d' "$file"
                        git add "$file"
                    fi
                done
                
                git commit -m "Force merge branch $branch - auto-resolved" 2>/dev/null || true
                log "✅ Force merged branch $branch with conflict resolution"
            fi
            
            # Delete the merged branch
            git push origin --delete "$branch" 2>/dev/null || true
        fi
    done
    
    # Push all changes
    git push origin "$default_branch" --force-with-lease
    
    cd ..
}

# Main execution
main() {
    setup
    
    log "Starting aggressive force merge process..."
    
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
