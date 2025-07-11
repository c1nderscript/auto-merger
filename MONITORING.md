# Monitoring Guide for Auto-Merge System

## Critical Monitoring Requirements

### 1. Log File Size Monitoring - HIGH PRIORITY ⚠️

**Issue**: The force-merge job frequency has been increased by 10× (from previous schedule).

**Critical Path**: `/var/log/force-merge.log`

**Action Required**: Implement periodic monitoring of this log file to prevent disk space exhaustion.

#### Monitoring Schedule
- **Weekly**: Manual check of log file size
- **Monthly**: Review log retention policies
- **Quarterly**: Audit disk usage patterns

#### Monitoring Commands
```bash
# Check current log file size
ls -lh /var/log/force-merge.log

# Check disk usage for /var/log partition
df -h /var/log

# Check log growth rate (run twice with time interval)
stat /var/log/force-merge.log

# Count log entries (to estimate activity)
wc -l /var/log/force-merge.log
```

#### Alert Thresholds
- **Warning**: Log file > 50MB
- **Critical**: Log file > 100MB
- **Emergency**: /var/log partition > 90% full

#### Remediation Actions
1. **Immediate**: Rotate current log file
2. **Short-term**: Implement log rotation (logrotate)
3. **Long-term**: Set up automated cleanup and archival

### 2. Disk Space Monitoring
Monitor `/var/log` partition usage due to increased logging activity.

### 3. Log Rotation Setup (Recommended)
Create `/etc/logrotate.d/force-merge`:
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

## Monitoring Integration

### Dashboard Metrics
- Log file size (bytes)
- Log growth rate (bytes/hour)
- Disk usage percentage (/var/log)
- Number of merge operations per hour

### Alerting Rules
- Log file size > 50MB → Warning
- Log file size > 100MB → Critical
- /var/log disk usage > 85% → Warning
- /var/log disk usage > 95% → Critical

## Regular Maintenance Tasks

### Weekly
- [ ] Check `/var/log/force-merge.log` size
- [ ] Verify log rotation is working
- [ ] Check disk space usage

### Monthly
- [ ] Review log retention policies
- [ ] Clean up old archived logs
- [ ] Update monitoring thresholds if needed

### Quarterly
- [ ] Audit overall logging strategy
- [ ] Review disk usage trends
- [ ] Update monitoring documentation

---
**Last Updated**: $(date)
**Next Review**: $(date -d '+3 months')
