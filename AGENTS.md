# agents.md - Auto-Merge GitHub Repository System

## Project Overview

This repository contains an automated GitHub repository management system that performs auto-merging of pull requests and branches across multiple repositories. The system is designed for AI-generated code workflows and experimental development environments where rapid integration is prioritized over traditional code review processes.

**Primary Purpose**: Automate the merging of GitHub pull requests and branches when they meet specific criteria (no conflicts, clean merge state).

**Key Features**:
- Automated scanning of all user repositories
- Safe auto-merging of conflict-free pull requests
- Direct branch merging when no PRs exist
- Aggressive force-merge capability for experimental workflows
- Comprehensive logging and monitoring
- Cron job integration for continuous operation

## Technology Stack

- **Primary Language**: Bash
- **GitHub Integration**: GitHub CLI (gh), Git
- **Scheduling**: Linux cron
- **Dependencies**: jq (JSON processor)
- **Logging**: Custom file-based logging with rotation support
- **Monitoring**: Script-based log size monitoring

## Project Structure

```
auto-merger/
├── merge.sh                    # Main auto-merge script (safe mode)
├── aggro.sh                   # Aggressive force-merge script
├── setup-env.sh              # Environment setup and validation
├── check-log-size.sh          # Log monitoring script
├── README.md                  # Setup and usage documentation
├── README.md.backup           # Backup of documentation
└── MONITORING.md              # Critical monitoring guidelines
```

## Current Task Context

**Active Development Areas**:
- Log file size management (CRITICAL PRIORITY)
- Cron job frequency optimization (recently increased 10×)
- Force-merge workflow for AI-generated code
- Disk space monitoring for `/var/log` partition

**Known Issues**:
- Log file growth due to increased job frequency
- Need for automated log rotation implementation
- Disk space monitoring requirements

## Development Guidelines

### Script Organization
- **merge.sh**: Production-safe auto-merge with conflict detection
- **aggro.sh**: Experimental force-merge for AI workflows (bypasses safety checks)
- **setup-env.sh**: Environment variable management and validation
- **check-log-size.sh**: Monitoring and alerting for log file sizes

### Environment Configuration
```bash
# Required environment variables (set in /opt/scripts/auto-merge.env)
export GITHUB_TOKEN="your_github_personal_access_token_here"
export GITHUB_USERNAME="your_github_username"
export GITHUB_APP_KEY="/root/automerge/github-app-private-key.pem"  # path to GitHub App private key
```

### Safety Features
- Merge state validation (MERGEABLE and CLEAN status required)
- Conflict detection before attempting merges
- Branch protection awareness
- Comprehensive error logging
- Retry mechanisms with backoff

### Naming Conventions
- Scripts: `kebab-case.sh`
- Log files: `/var/log/[component]-[type].log`
- Environment files: `[component].env`
- Temporary directories: `/tmp/[component]-[purpose]`

## Codex Integration Instructions

### Context Management
When working with this codebase, Codex agents should:

1. **Always check environment setup first**:
   ```bash
   source /opt/scripts/auto-merge.env
   ./setup-env.sh
   ```

2. **Monitor log file sizes before operations**:
   ```bash
   ./check-log-size.sh
   ```

3. **Use appropriate script for task**:
   - Safe merging: `./merge.sh`
   - Force merging: `./aggro.sh` (use with caution)

### Multi-Step Task Instructions

#### Adding New Repository Support
1. Verify GitHub token permissions
2. Test with single repository first
3. Update repository filtering logic if needed
4. Monitor log output for new patterns

#### Modifying Merge Behavior
1. Always backup current script version
2. Test changes in isolated environment
3. Verify safety checks remain intact
4. Update documentation for new behaviors

#### Log Management Tasks
1. Check current log sizes: `ls -lh /var/log/force-merge.log`
2. Implement log rotation if size > 50MB
3. Archive old logs before cleanup
4. Verify disk space after operations

### Error Handling and Recovery

#### Common Issues and Solutions
- **Authentication failures**: Check token expiration and permissions
- **Merge conflicts**: Script will skip automatically, manual review required
- **Repository access**: Verify token scope includes target repositories
- **Disk space**: Run log cleanup before continuing operations

#### Recovery Procedures
1. **Failed merge state**: Reset repository to known good state
2. **Log file overflow**: Immediate rotation and cleanup
3. **Authentication issues**: Regenerate token and update environment
4. **Cron job failures**: Check system resources and permissions

## Performance Optimization

### Log Management Strategy
- **Warning threshold**: 50MB log file size
- **Critical threshold**: 100MB log file size
- **Rotation schedule**: Daily with 7-day retention
- **Monitoring frequency**: Weekly manual checks

### Resource Usage
- **Memory**: Minimal footprint, primarily I/O bound
- **Network**: GitHub API rate limits apply
- **Disk**: Monitor `/var/log` partition usage
- **CPU**: Low usage, primarily waiting on network operations

### Batch Processing Optimization
- Process repositories in parallel where safe
- Implement backoff for API rate limiting
- Cache repository metadata when possible
- Use efficient GitHub CLI queries

## Testing Strategy

### Manual Testing
```bash
# Test environment setup
./setup-env.sh

# Test single repository (safe mode)
GITHUB_USERNAME=testuser ./merge.sh

# Test log monitoring
./check-log-size.sh

# Test force merge (use carefully)
./aggro.sh
```

### Integration Testing
- Verify cron job execution: `sudo tail -f /var/log/auto-merge-cron.log`
- Monitor GitHub API responses
- Check merge success rates in detailed logs
- Validate log rotation functionality

### Safety Testing
- Test with repositories containing conflicts
- Verify branch protection respect
- Test token permission boundaries
- Validate error handling paths

## Deployment Process

### Initial Setup
1. Install prerequisites (GitHub CLI, jq)
2. Create script directory: `/opt/scripts/`
3. Set up environment variables file
4. Configure cron job with appropriate frequency
5. Set up log monitoring alerts

### Production Deployment
```bash
sudo mkdir -p /opt/scripts
sudo cp *.sh /opt/scripts/
sudo chmod +x /opt/scripts/*.sh
sudo nano /opt/scripts/auto-merge.env  # Add tokens
crontab -e  # Add cron schedule
```

### Monitoring Setup
```bash
# Weekly log check (add to cron)
0 9 * * 1 /opt/scripts/check-log-size.sh

# Log rotation setup
sudo nano /etc/logrotate.d/auto-merge
```

## Security Considerations

### GitHub Token Management
- Use personal access tokens with minimal required permissions
- Store tokens in secure environment files (600 permissions)
- Rotate tokens regularly
- Monitor token usage in GitHub audit logs

### Repository Access
- Verify token scope before deployment
- Test with non-production repositories first
- Implement repository whitelist/blacklist if needed
- Monitor merge activities for unexpected patterns

### Log Security
- Ensure log files don't contain sensitive data
- Set appropriate file permissions (640)
- Implement log cleanup for old entries
- Consider log encryption for sensitive environments

## Monitoring and Alerting

### Critical Metrics
- **Log file size**: Monitor `/var/log/force-merge.log`
- **Disk usage**: Monitor `/var/log` partition
- **API rate limits**: Track GitHub API usage
- **Merge success rates**: Monitor successful/failed operations

### Alert Thresholds
- **Warning**: Log file > 50MB
- **Critical**: Log file > 100MB
- **Emergency**: `/var/log` partition > 90% full
- **API limits**: Approaching GitHub rate limits

### Monitoring Commands
```bash
# Check log size
ls -lh /var/log/force-merge.log

# Check disk usage
df -h /var/log

# Monitor recent activity
tail -f /var/log/auto-merge-cron.log

# Check API rate limits
gh api rate_limit
```

## Troubleshooting Guide

### Common Issues

#### Issue 1: Log file growing too large
**Symptoms**: Disk space warnings, slow system performance
**Solution**: 
```bash
# Immediate: Rotate current log
sudo mv /var/log/force-merge.log /var/log/force-merge.log.$(date +%Y%m%d)
sudo gzip /var/log/force-merge.log.$(date +%Y%m%d)

# Long-term: Set up logrotate
sudo nano /etc/logrotate.d/auto-merge
```

#### Issue 2: GitHub authentication failures
**Symptoms**: "authentication failed" in logs
**Solution**:
```bash
# Check token validity
gh auth status

# Regenerate token and update environment
nano /opt/scripts/auto-merge.env
```

#### Issue 3: Merge conflicts preventing automation
**Symptoms**: PRs skipped with "not mergeable" status
**Solution**: Manual review required, conflicts must be resolved by developers

### Debug Mode
Enable verbose logging by modifying scripts:
```bash
# Add to beginning of scripts
set -x  # Enable debug output
```

## Best Practices

### Repository Management
- Review merge patterns regularly
- Maintain whitelist of safe repositories for auto-merge
- Implement branch naming conventions
- Use descriptive commit messages for automated merges

### Operational Excellence
- Monitor log files weekly
- Test scripts in staging environment
- Keep backup copies of working configurations
- Document any custom modifications

### Security Hygiene
- Rotate GitHub tokens quarterly
- Review repository access permissions
- Monitor for unusual merge patterns
- Implement least-privilege access

---

## Recent Updates

**2024-07-11**: Added critical log monitoring requirements due to 10× frequency increase
**2024-07-11**: Updated force-merge workflow for AI-generated code integration
**2024-07-11**: Enhanced monitoring documentation and alert thresholds

---

*This agents.md file is optimized for AI agent interaction and provides comprehensive context for automated development workflows.*
