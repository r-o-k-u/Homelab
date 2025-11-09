# ⚙️ Operations Guide

Day-to-day management, maintenance, updates, backups, and monitoring for your homelab.

---

## 📑 Table of Contents

- [Daily Operations](#-daily-operations)
- [Service Management](#-service-management)
- [Monitoring & Health](#-monitoring--health)
- [Backups](#-backups)
- [Updates & Maintenance](#-updates--maintenance)
- [Log Management](#-log-management)
- [Performance Optimization](#-performance-optimization)
- [Disaster Recovery](#-disaster-recovery)

---

## 📅 Daily Operations

### Morning Routine (5 minutes)

```bash
# 1. Check service health
./scripts/health-check.sh

# 2. View any failed services
docker compose ps --filter "status=exited"

# 3. Check disk usage
df -h

# 4. Review recent logs for errors
docker compose logs --tail=50 --since=24h | grep -i error
```

### Quick Service Check

```bash
# One-liner health check
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# Count running services
docker compose ps --services --filter "status=running" | wc -l

# Check resource usage
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

---

## 🎛️ Service Management

### Starting Services

```bash
# Start all services
docker compose up -d

# Start specific profile
docker compose --profile media up -d

# Start specific service
docker compose up -d jellyfin

# Start with rebuild
docker compose up -d --build
```

### Stopping Services

```bash
# Stop all services
docker compose down

# Stop specific service
docker compose stop jellyfin

# Stop and remove volumes (⚠️ CAUTION: Data loss!)
docker compose down -v

# Stop specific profile
docker compose --profile media down
```

### Restarting Services

```bash
# Restart all services
docker compose restart

# Restart specific service
docker compose restart jellyfin

# Restart multiple services
docker compose restart jellyfin sonarr radarr

# Force recreate container
docker compose up -d --force-recreate jellyfin
```

### Scaling Services

```bash
# Scale a service (if supported)
docker compose up -d --scale worker=3

# View service scale
docker compose ps worker
```

### Service Status

```bash
# View all services
docker compose ps

# View specific service details
docker compose ps jellyfin

# View service ports
docker compose port jellyfin 8096

# View service logs
docker compose logs jellyfin

# Follow logs in real-time
docker compose logs -f jellyfin

# View last 100 lines
docker compose logs --tail=100 jellyfin

# Filter logs by time
docker compose logs --since=1h jellyfin
docker compose logs --since=2024-01-01T00:00:00 jellyfin
```

---

## 📊 Monitoring & Health

### Health Check Script

The included `health-check.sh` script provides comprehensive monitoring:

```bash
./scripts/health-check.sh
```

**Output includes:**
- Docker status
- Container health
- Disk usage
- Resource utilization
- Network connectivity
- Unhealthy containers

### Manual Health Checks

```bash
# Check container health status
docker ps --filter "health=unhealthy" --format "table {{.Names}}\t{{.Status}}"

# Inspect specific container health
docker inspect --format='{{json .State.Health}}' jellyfin | jq

# View health check logs
docker inspect jellyfin | jq '.[0].State.Health.Log'

# Test service endpoint
curl -I http://localhost:7096  # Jellyfin
curl -I http://localhost:7453  # Navidrome
```

### Uptime Kuma Monitoring

**Setup Monitors:**

1. Access Uptime Kuma: `http://localhost:7001`
2. Add monitors for each service:
   - **Type**: HTTP(s)
   - **URL**: Service endpoint
   - **Interval**: 60 seconds
   - **Retries**: 3

**Example Monitors:**

| Service | URL | Expected Status |
|---------|-----|-----------------|
| Jellyfin | `http://jellyfin:8096` | 200 |
| Navidrome | `http://navidrome:4533` | 200 |
| Home Assistant | `http://home-assistant:8123` | 200 |
| Traefik | `http://traefik:8080/api/http/routers` | 200 |

**Configure Notifications:**

1. Settings → Notifications
2. Add notification method:
   - Email
   - Discord
   - Telegram
   - Slack
   - Webhook
3. Test notification
4. Apply to monitors

### Resource Monitoring

```bash
# Real-time resource usage
docker stats

# One-time snapshot
docker stats --no-stream

# Specific containers
docker stats jellyfin navidrome

# Export to CSV
docker stats --no-stream --format "{{.Container}},{{.CPUPerc}},{{.MemUsage}}" > stats.csv
```

### InfluxDB + Grafana Monitoring

**Setup InfluxDB Data Source in Grafana:**

1. Access Grafana: `http://localhost:7300`
2. Configuration → Data Sources → Add
3. Select InfluxDB
4. Configure:
   ```
   URL: http://influxdb:8086
   Organization: homelab
   Token: [from .env]
   Default Bucket: metrics
   ```

**Import Dashboards:**

1. Create → Import
2. Use ID or JSON:
   - Docker Container Stats: 1150
   - System Monitoring: 928
   - Home Assistant: 13748

### Network Monitoring

```bash
# List networks
docker network ls

# Inspect network
docker network inspect traefik

# View network containers
docker network inspect traefik --format='{{range .Containers}}{{.Name}} {{end}}'

# Test connectivity between containers
docker compose exec jellyfin ping postgres
docker compose exec jellyfin nc -zv postgres 5432
```

---

## 💾 Backups

### Automated Backup Script

The included `backup.sh` script handles:
- Configuration backups
- Database dumps
- Environment files
- Docker Compose files

```bash
# Run manual backup
./scripts/backup.sh

# View backups
ls -lh backups/

# Backup specific service
docker compose exec postgres pg_dump -U homelab_user homelab > backup.sql
```

### Backup Strategy

**What to Backup:**

| Data Type | Location | Frequency | Method |
|-----------|----------|-----------|--------|
| **Configurations** | `config/` | Daily | `tar` archive |
| **Databases** | PostgreSQL, InfluxDB | Daily | Database dump |
| **Media** | `media/` | Weekly | Rsync/Rclone |
| **Environment** | `.env` | On change | Copy |
| **Compose** | `docker-compose.yml` | On change | Copy |

### Manual Backup Commands

**PostgreSQL:**
```bash
# Backup single database
docker compose exec postgres pg_dump -U homelab_user homelab > homelab_backup.sql

# Backup all databases
docker compose exec postgres pg_dumpall -U homelab_user > all_databases.sql

# Backup specific table
docker compose exec postgres pg_dump -U homelab_user -t users homelab > users_backup.sql
```

**Redis:**
```bash
# Trigger save
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} SAVE

# Copy RDB file
docker compose cp redis:/data/dump.rdb ./backups/redis_$(date +%Y%m%d).rdb
```

**InfluxDB:**
```bash
# Backup
docker compose exec influxdb influx backup /tmp/influxdb_backup
docker compose cp influxdb:/tmp/influxdb_backup ./backups/

# Restore
docker compose cp ./backups/influxdb_backup influxdb:/tmp/
docker compose exec influxdb influx restore /tmp/influxdb_backup
```

**Configuration Files:**
```bash
# Backup all configs
tar -czf config_backup_$(date +%Y%m%d).tar.gz config/

# Backup specific service
tar -czf jellyfin_config_$(date +%Y%m%d).tar.gz config/jellyfin/
```

### Cloud Backup with Rclone

**Install Rclone:**
```bash
# Linux
sudo apt install rclone

# macOS
brew install rclone

# Configure
rclone config
```

**Backup to Cloud:**
```bash
# Sync to cloud storage
rclone sync backups/ remote:homelab-backups --progress

# One-time copy
rclone copy backups/ remote:homelab-backups --progress

# Encrypted backup
rclone sync backups/ remote:homelab-backups --crypt-remote --progress
```

### Automated Backup Schedule

**Linux/macOS (cron):**
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /path/to/homelab && ./scripts/backup.sh >> /var/log/homelab_backup.log 2>&1

# Weekly cloud sync at 3 AM Sunday
0 3 * * 0 rclone sync /path/to/homelab/backups remote:homelab-backups
```

**Windows (Task Scheduler):**
1. Open Task Scheduler
2. Create Basic Task
3. Trigger: Daily at 2:00 AM
4. Action: Start Program
5. Program: `bash`
6. Arguments: `-c "cd /path/to/homelab && ./scripts/backup.sh"`

---

## 🔄 Updates & Maintenance

### Update Strategy

**Before Updating:**
1. ✅ Create backup
2. ✅ Check release notes
3. ✅ Plan maintenance window
4. ✅ Notify users (if applicable)

### Updating Docker Images

```bash
# Pull latest images for all services
docker compose pull

# Pull specific service
docker compose pull jellyfin

# View available updates
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Update and restart
docker compose up -d

# Update specific service
docker compose up -d jellyfin
```

### Updating Single Service

```bash
# 1. Pull new image
docker compose pull jellyfin

# 2. Stop service
docker compose stop jellyfin

# 3. Remove container (config preserved)
docker compose rm jellyfin

# 4. Start with new image
docker compose up -d jellyfin

# 5. Verify
docker compose ps jellyfin
docker compose logs jellyfin
```

### Rolling Updates (Zero Downtime)

```bash
# Update one service at a time
for service in jellyfin sonarr radarr; do
    echo "Updating $service..."
    docker compose pull $service
    docker compose up -d --no-deps $service
    sleep 10
    docker compose ps $service
done
```

### Update Verification

```bash
# Check container creation date
docker inspect jellyfin --format='{{.Created}}'

# View image history
docker history $(docker compose images -q jellyfin)

# Compare image IDs
docker compose images

# Test service functionality
curl -I http://localhost:7096
```

### Rollback

```bash
# View image history
docker images jellyfin

# Tag current as rollback
docker tag jellyfin:latest jellyfin:rollback

# Pull specific version
docker pull linuxserver/jellyfin:10.8.13

# Update compose to use specific version
# docker-compose.yml:
#   image: linuxserver/jellyfin:10.8.13

# Apply
docker compose up -d jellyfin
```

### System Maintenance

**Weekly Tasks:**
```bash
# Clean up unused images
docker image prune -a -f

# Clean up unused volumes (⚠️ CAUTION)
docker volume prune -f

# Clean up unused networks
docker network prune -f

# Complete cleanup
docker system prune -a --volumes -f
```

**Monthly Tasks:**
```bash
# Update host system
sudo apt update && sudo apt upgrade -y  # Ubuntu/Debian
sudo dnf update -y                       # Fedora/RHEL

# Update Docker
# Follow official Docker update guide

# Review and rotate logs
docker compose logs --tail=1000 > monthly_logs_$(date +%Y%m).log

# Check disk health
sudo smartctl -a /dev/sda

# Verify backups
ls -lh backups/ | tail -10
```

---

## 📝 Log Management

### Viewing Logs

```bash
# View all logs
docker compose logs

# Specific service
docker compose logs jellyfin

# Follow logs (real-time)
docker compose logs -f jellyfin

# Multiple services
docker compose logs jellyfin sonarr radarr

# Last N lines
docker compose logs --tail=100 jellyfin

# Since specific time
docker compose logs --since=1h jellyfin
docker compose logs --since="2024-01-01 00:00:00" jellyfin

# Filter by log level
docker compose logs jellyfin | grep ERROR
docker compose logs jellyfin | grep -E "ERROR|WARN"
```

### Log Rotation

**Configure Docker Logging:**

Edit `/etc/docker/daemon.json`:
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "labels": "production",
    "env": "os,customer"
  }
}
```

Restart Docker:
```bash
sudo systemctl restart docker
```

**Per-Service Logging:**
```yaml
# In docker-compose.yml
services:
  jellyfin:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### Exporting Logs

```bash
# Export to file
docker compose logs > homelab_logs_$(date +%Y%m%d).log

# Export with timestamps
docker compose logs --timestamps > logs_with_time.log

# Export errors only
docker compose logs 2>&1 | grep -i error > errors.log

# Export to remote syslog
# In docker-compose.yml:
logging:
  driver: "syslog"
  options:
    syslog-address: "tcp://192.168.1.200:514"
```

### Log Analysis

```bash
# Count errors
docker compose logs | grep -c ERROR

# Find most common errors
docker compose logs | grep ERROR | sort | uniq -c | sort -rn | head -10

# Search for specific issue
docker compose logs jellyfin | grep -i "database"

# View logs in JSON format
docker compose logs --no-log-prefix jellyfin | jq

# Analyze response times
docker compose logs traefik | grep "Duration" | awk '{print $NF}' | sort -n
```

---

## ⚡ Performance Optimization

### Resource Limits

**Set Resource Constraints:**
```yaml
# In docker-compose.yml
services:
  jellyfin:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G
```

### Database Optimization

**PostgreSQL:**
```bash
# Analyze database
docker compose exec postgres psql -U homelab_user -d homelab -c "ANALYZE;"

# Vacuum database
docker compose exec postgres psql -U homelab_user -d homelab -c "VACUUM FULL;"

# Check database size
docker compose exec postgres psql -U homelab_user -c "\l+"

# Check table sizes
docker compose exec postgres psql -U homelab_user -d homelab -c "\dt+"
```

**Redis:**
```bash
# Check memory usage
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} INFO memory

# Flush rarely used data
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} FLUSHDB

# Optimize memory
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} CONFIG SET maxmemory-policy allkeys-lru
```

### Media Optimization

**Jellyfin Transcoding:**
1. Enable hardware acceleration (if available)
2. Optimize quality presets
3. Clean transcoding cache regularly

```bash
# Clean transcode cache
docker compose exec jellyfin rm -rf /config/transcodes/*
```

### Disk Optimization

```bash
# Find large files
find config/ -type f -size +100M -exec ls -lh {} \;

# Clear Docker build cache
docker builder prune -a -f

# Clear unused images
docker image prune -a -f

# Optimize media storage
# Use tools like HandBrake for video compression
```

---

## 🚨 Disaster Recovery

### Recovery Scenarios

#### Scenario 1: Single Service Failure

```bash
# 1. Check logs
docker compose logs jellyfin

# 2. Restart service
docker compose restart jellyfin

# 3. If still failing, recreate
docker compose up -d --force-recreate jellyfin

# 4. Restore from backup if needed
docker compose stop jellyfin
rm -rf config/jellyfin/*
tar -xzf backups/jellyfin_config.tar.gz -C config/
docker compose up -d jellyfin
```

#### Scenario 2: Database Corruption

```bash
# 1. Stop services using database
docker compose stop n8n outline

# 2. Stop database
docker compose stop postgres

# 3. Backup current state
docker compose cp postgres:/var/lib/postgresql/data ./postgres_corrupt

# 4. Restore from backup
docker compose exec postgres psql -U homelab_user < backups/postgres_backup.sql

# 5. Restart
docker compose up -d postgres
docker compose up -d n8n outline
```

#### Scenario 3: Complete System Failure

```bash
# 1. Fresh installation
# Follow QUICKSTART.md

# 2. Restore .env
cp backups/latest/.env.backup .env

# 3. Restore configs
tar -xzf backups/latest/config_backup.tar.gz

# 4. Restore databases
docker compose up -d postgres redis
sleep 10
docker compose exec postgres psql -U homelab_user < backups/latest/postgres_dump.sql

# 5. Start all services
docker compose up -d

# 6. Verify
./scripts/health-check.sh
```

### Recovery Testing

**Monthly Recovery Drill:**
```bash
# 1. Create test backup
./scripts/backup.sh

# 2. Stop random service
docker compose stop jellyfin

# 3. Corrupt config (in test environment!)
docker compose exec jellyfin rm /config/config/system.xml

# 4. Restore from backup
tar -xzf backups/latest/config_backup.tar.gz -C config/

# 5. Restart and verify
docker compose up -d jellyfin
curl -I http://localhost:7096
```

### Emergency Contacts

Document these:
- [ ] System administrator contact
- [ ] Backup storage location
- [ ] Important service credentials
- [ ] Recovery procedure location

---

## 📋 Maintenance Checklist

### Daily
- [ ] Check service health
- [ ] Review error logs
- [ ] Verify disk space
- [ ] Check Uptime Kuma alerts

### Weekly
- [ ] Run backup script
- [ ] Clean Docker resources
- [ ] Review resource usage
- [ ] Check for updates

### Monthly
- [ ] Update all services
- [ ] Test backup restore
- [ ] Review and rotate logs
- [ ] Check certificate expiry
- [ ] Review security logs
- [ ] Optimize databases

### Quarterly
- [ ] Full system backup
- [ ] Security audit
- [ ] Disaster recovery test
- [ ] Documentation update
- [ ] Performance review

---

## 📚 Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Operations Best Practices](https://www.docker.com/blog/docker-best-practices/)
- [Backup Strategies](https://docs.docker.com/storage/volumes/#backup-restore-or-migrate-data-volumes)

---

[⬅ Back to Main README](../README.md)