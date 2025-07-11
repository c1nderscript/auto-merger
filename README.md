# Auto-Merge Cron Job Setup

## Prerequisites

1. **Install GitHub CLI:**
   ```bash
   # On Ubuntu/Debian
   sudo apt install gh
   
   # On macOS
   brew install gh
   
   # On other systems, see: https://cli.github.com/manual/installation
   ```

2. **Install jq (JSON processor):**
   ```bash
   # On Ubuntu/Debian
   sudo apt install jq
   
   # On macOS
   brew install jq
   ```

## Setup Instructions

1. **Save the script to a permanent location:**
   ```bash
   sudo mkdir -p /opt/scripts
   sudo cp merge.sh /opt/scripts/
   sudo chmod +x /opt/scripts/merge.sh
   ```

2. **Create log directory for all scripts:**
   ```bash
   sudo mkdir -p /var/log/auto-merge
   sudo chmod 755 /var/log/auto-merge
   ```

3. **Create environment variables file:**
   ```bash
   sudo nano /opt/scripts/auto-merge.env
   ```
   
   Add your configuration:
   ```bash
   export GITHUB_TOKEN="your_github_personal_access_token_here"
   export GITHUB_USERNAME="your_github_username"
   # Optional: used by aggro.sh when GitHub App auth fails
   export GITHUB_TOKEN_FALLBACK="fallback_token"
   ```

4. **Validate your environment:**
   ```bash
   ./setup-env.sh
   ```

5. **Create a wrapper script:**
   ```bash
   sudo nano /opt/scripts/auto-merge-wrapper.sh
   ```
   
   Content:
   ```bash
   #!/bin/bash
   source /opt/scripts/auto-merge.env
   /opt/scripts/merge.sh --parallel 4
   ```
   
   Make it executable:
   ```bash
   sudo chmod +x /opt/scripts/auto-merge-wrapper.sh
   ```

6. **Set up the cron job:**
   ```bash
   crontab -e
   ```
   
   Add this line to run every 5 minutes:
   ```
   */5 * * * * /opt/scripts/auto-merge-wrapper.sh >> /var/log/auto-merge/cron.log 2>&1
   ```

## GitHub Personal Access Token

Create a GitHub Personal Access Token with these permissions:
- `repo` (Full control of private repositories)
- `workflow` (Update GitHub Action workflows)
- `read:org` (Read org and team membership)

Generate token at: https://github.com/settings/tokens

## Additional Scripts

- `aggro.sh` &mdash; Force merges all open pull requests and branches. Run only after
  executing `setup-env.sh` when you need to bypass safety checks.
- `check-log-size.sh` &mdash; Reports the size of `/var/log/auto-merge/force-merge.log` and
  warns if the file should be rotated. Useful for weekly maintenance.
- `rotate-log-if-needed.sh` &mdash; Calls `logrotate` when the log exceeds 100MB using the provided configuration.

## Configuration Options

You can modify these variables in the script:

- `LOG_FILE`: Where to store detailed logs
- `REPO_DIR`: Temporary directory for cloning repos
- `MAX_RETRIES`: Number of retry attempts for failed operations
- `--parallel [N]`: Enable parallel processing with up to `N` concurrent jobs. If `N` is omitted, the default is 4.

## Monitoring

- **Check logs:** `tail -f /var/log/auto-merge/cron.log`
- **Detailed logs:** `tail -f /var/log/auto-merge/merge.log`
- **Test manually:** `/opt/scripts/auto-merge-wrapper.sh`

### ⚠️ Important: Log File Size Monitoring

**CRITICAL**: The force-merge job now runs 10× more frequently. You must periodically review `/var/log/auto-merge/force-merge.log` file size to prevent disk space issues.

**Recommended actions:**
- Monitor log file size weekly: `ls -lh /var/log/auto-merge/force-merge.log`
- Set up log rotation if the file grows large (>100MB)
- Install the sample logrotate config `force-merge.logrotate` to `/etc/logrotate.d/force-merge`
- Consider implementing automated log cleanup for files older than 30 days
- Add disk space monitoring alerts for the `/var/log` directory

**Quick commands:**
```bash
# Check current log size
ls -lh /var/log/auto-merge/force-merge.log

# Check disk usage
df -h /var/log

# Run the helper script
./check-log-size.sh

# Automatically rotate the log when it grows too large
./rotate-log-if-needed.sh

# Archive old logs (example)
sudo gzip /var/log/auto-merge/force-merge.log.old
```

### Log Rotation Setup

Create `/etc/logrotate.d/force-merge` to keep the log file size under control:

```
/var/log/force-merge.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    postrotate
        # Signal process to reopen log file if needed
    endscript
}
```

Test the configuration manually:

```bash
sudo logrotate --force /etc/logrotate.d/force-merge
```

`merge.sh` and `aggro.sh` automatically invoke `check-log-size.sh` at startup.
If the log file exceeds the critical threshold, the script exits without
performing merges. Set `SKIP_LOG_SIZE_CHECK=1` to bypass this check when
testing.

## Safety Features

The script includes several safety measures:
- Only merges PRs marked as "MERGEABLE" and "CLEAN"
- Double-checks merge status before attempting merge
- Uses `--auto` flag for PR merges (waits for required checks)
- Logs all operations with timestamps
- Handles errors gracefully

## Customization

To modify the merge behavior:
- Change `--squash` to `--merge` or `--rebase` for different merge strategies
- Uncomment branch deletion lines to auto-delete merged branches
- Adjust the repository limit in `get_repositories()` function
- Add filters for specific repositories or branch patterns

## Force Merge Option (`aggro.sh`)

Use `aggro.sh` when you need to aggressively merge branches without the usual
safety checks. This script is intended for experimental workflows and will merge
branches even when conflicts or failing checks exist.

If GitHub App authentication fails, `aggro.sh` falls back to the token defined in
`GITHUB_TOKEN_FALLBACK`.

```bash
source /opt/scripts/auto-merge.env
./aggro.sh
```

⚠️ **Warning**: `aggro.sh` bypasses all merge protections and can easily break
repositories. Monitor `/var/log/auto-merge/force-merge.log` and only run it on disposable
branches or test environments.

## Troubleshooting

1. **Permission denied:** Ensure scripts are executable and paths are correct
2. **GitHub authentication failed:** Check your token permissions and expiration
3. **No repositories found:** Verify your username and token have access to repos
4. **Merge failures:** Check the detailed logs for specific error messages
