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

2. **Create environment variables file:**
   ```bash
   sudo nano /opt/scripts/auto-merge.env
   ```
   
   Add your configuration:
   ```bash
   export GITHUB_TOKEN="your_github_personal_access_token_here"
   export GITHUB_USERNAME="your_github_username"
   ```

3. **Validate your environment:**
   ```bash
   ./setup-env.sh
   ```

4. **Create a wrapper script:**
   ```bash
   sudo nano /opt/scripts/auto-merge-wrapper.sh
   ```
   
   Content:
   ```bash
   #!/bin/bash
   source /opt/scripts/auto-merge.env
   /opt/scripts/merge.sh
   ```
   
   Make it executable:
   ```bash
   sudo chmod +x /opt/scripts/auto-merge-wrapper.sh
   ```

5. **Set up the cron job:**
   ```bash
   crontab -e
   ```
   
   Add this line to run every 5 minutes:
   ```
   */5 * * * * /opt/scripts/auto-merge-wrapper.sh >> /var/log/auto-merge-cron.log 2>&1
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
- `check-log-size.sh` &mdash; Reports the size of `/var/log/force-merge.log` and
  warns if the file should be rotated. Useful for weekly maintenance.

## Configuration Options

You can modify these variables in the script:

- `LOG_FILE`: Where to store detailed logs
- `REPO_DIR`: Temporary directory for cloning repos
- `MAX_RETRIES`: Number of retry attempts for failed operations

## Monitoring

- **Check logs:** `tail -f /var/log/auto-merge-cron.log`
- **Detailed logs:** `tail -f /tmp/auto-merge.log`
- **Test manually:** `/opt/scripts/auto-merge-wrapper.sh`

### ⚠️ Important: Log File Size Monitoring

**CRITICAL**: The force-merge job now runs 10× more frequently. You must periodically review `/var/log/force-merge.log` file size to prevent disk space issues.

**Recommended actions:**
- Monitor log file size weekly: `ls -lh /var/log/force-merge.log`
- Set up log rotation if the file grows large (>100MB)
- Install the provided logrotate config:
  ```bash
  sudo cp logrotate/auto-merge /etc/logrotate.d/auto-merge
  ```
- Consider implementing automated log cleanup for files older than 30 days
- Add disk space monitoring alerts for the `/var/log` directory

**Quick commands:**
```bash
# Check current log size
ls -lh /var/log/force-merge.log

# Check disk usage
df -h /var/log

# Run the helper script
./check-log-size.sh

# Archive old logs (example)
sudo gzip /var/log/force-merge.log.old
```

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

```bash
source /opt/scripts/auto-merge.env
./aggro.sh
```

⚠️ **Warning**: `aggro.sh` bypasses all merge protections and can easily break
repositories. Monitor `/var/log/force-merge.log` and only run it on disposable
branches or test environments.

## Troubleshooting

1. **Permission denied:** Ensure scripts are executable and paths are correct
2. **GitHub authentication failed:** Check your token permissions and expiration
3. **No repositories found:** Verify your username and token have access to repos
4. **Merge failures:** Check the detailed logs for specific error messages
