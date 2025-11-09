# 🔧 Troubleshooting Guide

Comprehensive problem-solving guide for common issues, debugging techniques, and solutions.

---

## 📑 Table of Contents

- [Quick Diagnostics](#-quick-diagnostics)
- [Service Issues](#-service-issues)
- [Network Problems](#-network-problems)
- [SSL & Certificate Issues](#-ssl--certificate-issues)
- [Database Problems](#-database-problems)
- [Performance Issues](#-performance-issues)
- [Storage & Volume Issues](#-storage--volume-issues)
- [Platform-Specific Issues](#-platform-specific-issues)
- [Advanced Debugging](#-advanced-debugging)

---

## 🚀 Quick Diagnostics

### First Steps Checklist

When something isn't working:

1. ✅ Is Docker running?
2. ✅ Are services started?
3. ✅ Any error messages in logs?
4. ✅ Enough disk space?
5. ✅ Enough RAM?
6. ✅ Network connectivity?

### Quick Diagnostic Commands

```bash
# 1. Docker status
docker info
systemctl status docker  # Linux

# 2. Service status
docker compose ps

# 3. View recent errors
docker compose logs --since=10m | grep -i error

# 4. System resources
df -h
free -h
docker stats --no-stream

# 5. Network connectivity
ping 8.8.8.8
curl https://google.com
```

### Health Check Script

```bash
# Run comprehensive health check
./scripts/health-check.sh

# Check specific service
docker compose ps jellyfin
docker inspect jellyfin | jq '.[0].State.Health'
```

---

## 🐋 Service Issues

### Service Won't Start

**Symptoms:**
- Service shows "exited" status
- Container starts then immediately stops
- "Cannot start service" error

**Diagnosis:**
```bash
# View service status
docker compose ps jellyfin

# Check logs
docker compose logs jellyfin

# Inspect container
docker inspect jellyfin
```

**Common Causes & Solutions:**

#### 1. Port Already in Use
```bash
# Find what's using the port
sudo lsof -i :7096  # Linux/macOS
netstat -ano | findstr :7096  # Windows

# Solution: Change port in .env
JELLYFIN_PORT=9096

# Or stop conflicting service
sudo systemctl stop service_name
```

#### 2. Missing Environment Variables
```bash
# Check .env file exists
ls -la .env

# Validate required variables
grep "POSTGRES_PASSWORD" .env

# Solution: Ensure all required vars are set
cp .env.example .env
nano .env
```

#### 3. Volume Permission Issues
```bash
# Check volume permissions
ls -ld config/jellyfin/

# Solution: Fix permissions
sudo chown -R $USER:$USER config/
sudo chmod -R 755 config/
```

#### 4. Configuration File Errors
```bash
# Check for syntax errors
docker compose config

# Validate YAML
yamllint docker-compose.yml

# Solution: Fix YAML syntax
# Common issues:
# - Incorrect indentation
# - Missing quotes
# - Invalid characters
```

### Service Keeps Restarting

**Symptoms:**
- Service in restart loop
- Status shows "Restarting (1) X seconds ago"

**Diagnosis:**
```bash
# Watch service status
watch docker compose ps jellyfin

# View detailed logs
docker compose logs -f jellyfin

# Check restart count
docker inspect jellyfin | jq '.[0].RestartCount'
```

**Solutions:**

```bash
# 1. Increase startup time
# In docker-compose.yml:
healthcheck:
  start_period: 120s  # Give more time

# 2. Check dependencies
docker compose ps postgres  # Must be healthy first

# 3. Remove and recreate
docker compose stop jellyfin
docker compose rm jellyfin
docker compose up -d jellyfin
```

### Service is Slow/Unresponsive

**Diagnosis:**
```bash
# Check resource usage
docker stats jellyfin

# Check process list
docker compose exec jellyfin ps aux

# Check disk I/O
iostat -x 1 5  # Linux
```

**Solutions:**

```bash
# 1. Increase resource limits
# In docker-compose.yml:
deploy:
  resources:
    limits:
      memory: 4G
      cpus: '2.0'

# 2. Check database connection
docker compose exec jellyfin ping postgres

# 3. Clear cache
docker compose exec jellyfin rm -rf /config/cache/*
docker compose restart jellyfin

# 4. Restart service
docker compose restart jellyfin
```

### Cannot Access Service UI

**Diagnosis:**
```bash
# Test from host
curl -I http://localhost:7096

# Test from container
docker compose exec heimdall curl -I http://jellyfin:8096

# Check port mapping
docker compose port jellyfin 8096
```

**Solutions:**

```bash
# 1. Verify service is running
docker compose ps jellyfin

# 2. Check port configuration
grep "JELLYFIN_PORT" .env

# 3. Verify port mapping in compose file
docker compose config | grep -A 5 "ports:"

# 4. Check firewall
sudo ufw status  # Linux
netsh advfirewall show allprofiles  # Windows

# 5. Test with container IP
docker inspect jellyfin | grep IPAddress
curl http://172.x.x.x:8096
```

---

## 🌐 Network Problems

### Cannot Access Services Externally

**Symptoms:**
- Works on localhost
- Doesn't work from other devices
- Domain doesn't resolve

**Diagnosis:**
```bash
# Check Docker networks
docker network ls
docker network inspect traefik

# Check Traefik routes
curl http://localhost:7080/api/http/routers

# Test DNS
nslookup media.lab.yourdomain.com

# Test from external
# Use: https://www.whatsmydns.net/
```

**Solutions:**

#### Domain Mode:
```bash
# 1. Verify DNS records
nslookup dashboard.lab.yourdomain.com

# 2. Check port forwarding
# Router should forward 80, 443 to server

# 3. Verify Traefik labels
docker compose config | grep "traefik.http.routers"

# 4. Check Traefik logs
docker compose logs traefik | grep -i error
```

#### Localhost Mode:
```bash
# 1. Get server IP
hostname -I

# 2. Test from other device
curl http://192.168.1.100:7096

# 3. Check firewall
sudo ufw allow 7096/tcp

# 4. Verify port binding
docker compose port jellyfin 8096
```

### Inter-Service Communication Fails

**Symptoms:**
- Services can't talk to each other
- "Unable to connect to database" errors
- "Could not resolve hostname" errors

**Diagnosis:**
```bash
# Check network membership
docker inspect jellyfin | grep Networks -A 10

# Test DNS resolution
docker compose exec jellyfin nslookup postgres

# Test connectivity
docker compose exec jellyfin ping postgres
docker compose exec jellyfin nc -zv postgres 5432
```

**Solutions:**

```bash
# 1. Verify both services on same network
# In docker-compose.yml:
services:
  jellyfin:
    networks:
      - traefik
      - internal  # <-- Add this

# 2. Check network exists
docker network create homelab_internal

# 3. Reconnect service to network
docker compose up -d --force-recreate jellyfin

# 4. Use container name as hostname
# Use "postgres" not "localhost"
# Use "redis" not "127.0.0.1"
```

### Traefik Routing Issues

**Diagnosis:**
```bash
# View Traefik dashboard
# http://localhost:7080

# Check routers
curl http://localhost:7080/api/http/routers | jq

# Check services
curl http://localhost:7080/api/http/services | jq

# View Traefik logs
docker compose logs traefik | grep -i "router\|service"
```

**Solutions:**

```bash
# 1. Verify service has correct labels
docker inspect jellyfin | grep Labels -A 20

# 2. Check service is on traefik network
docker inspect jellyfin | grep Networks -A 10

# 3. Verify domain in .env
grep "HOMELAB_DOMAIN" .env

# 4. Restart Traefik
docker compose restart traefik

# 5. Check for duplicate routes
docker compose config | grep "traefik.http.routers" | sort
```

---

## 🔒 SSL & Certificate Issues

### SSL Certificate Not Generated

**Symptoms:**
- "Certificate not found" error
- HTTPS doesn't work
- Browser security warning

**Diagnosis:**
```bash
# Check Traefik logs for ACME
docker compose logs traefik | grep -i acme

# View certificates
docker compose exec traefik ls -la /letsencrypt/
docker compose exec traefik cat /letsencrypt/acme.json | jq
```

**Solutions:**

#### 1. DNS Not Resolving
```bash
# Verify DNS from outside your network
nslookup media.lab.yourdomain.com 8.8.8.8

# Solution: Wait for DNS propagation (up to 48 hours)
# Or fix DNS records at registrar
```

#### 2. Port 80 Not Accessible
```bash
# Test from external source
curl http://yourdomain.com

# Solution: Enable port forwarding on router
# Forward: 80 → Server:80
```

#### 3. Rate Limit Hit
```bash
# Check logs for rate limit error
docker compose logs traefik | grep -i "rate limit"

# Solution: Use staging environment
# In docker-compose.yml (temporarily):
- --certificatesresolvers.myresolver.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory

# After fixing, remove staging line and delete acme.json
rm config/traefik/letsencrypt/acme.json
docker compose restart traefik
```

#### 4. Invalid Email
```bash
# Check email in .env
grep "TRAEFIK_EMAIL" .env

# Solution: Use valid email
TRAEFIK_EMAIL=your-real-email@example.com
```

### Certificate Expired

```bash
# Check certificate expiry
docker compose exec traefik cat /letsencrypt/acme.json | jq '.myresolver.Certificates[].domain.main'

# Force renewal
docker compose stop traefik
rm config/traefik/letsencrypt/acme.json
docker compose up -d traefik

# Watch renewal process
docker compose logs -f traefik
```

### Mixed Content Warnings

**Problem:** Some resources load via HTTP instead of HTTPS

**Solution:**
```yaml
# Add to service labels
labels:
  # Force HTTPS redirect
  - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"
  - "traefik.http.routers.jellyfin.middlewares=redirect-to-https"
  
  # Force SSL headers
  - "traefik.http.middlewares.ssl-header.headers.customresponseheaders.X-Forwarded-Proto=https"
```

---

## 🗄️ Database Problems

### PostgreSQL Won't Start

**Diagnosis:**
```bash
# Check logs
docker compose logs postgres

# Common errors to look for:
# - "database system was not properly shut down"
# - "could not create shared memory segment"
# - "data directory has wrong ownership"
```

**Solutions:**

#### 1. Improper Shutdown
```bash
# Check for lock files
docker compose exec postgres ls -la /var/lib/postgresql/data/

# Solution: Remove lock and restart
docker compose stop postgres
docker compose exec postgres rm /var/lib/postgresql/data/postmaster.pid
docker compose up -d postgres
```

#### 2. Permission Issues
```bash
# Check permissions
ls -ld config/postgres/data/

# Solution: Fix ownership
sudo chown -R 999:999 config/postgres/data/
docker compose up -d postgres
```

#### 3. Corrupted Data
```bash
# Backup current data
docker compose cp postgres:/var/lib/postgresql/data ./postgres_backup

# Restore from backup
docker compose stop postgres
rm -rf config/postgres/data/*
docker compose up -d postgres
# Then restore from SQL dump
docker compose exec postgres psql -U homelab_user < backups/postgres_dump.sql
```

### Cannot Connect to Database

**Diagnosis:**
```bash
# Test from host
docker compose exec postgres psql -U homelab_user -d homelab

# Test from another service
docker compose exec n8n nc -zv postgres 5432

# Check connection string
grep "DATABASE_URL" .env
```

**Solutions:**

```bash
# 1. Verify database is running
docker compose ps postgres

# 2. Check network connectivity
docker compose exec n8n ping postgres

# 3. Verify credentials
docker compose exec postgres psql -U homelab_user -d homelab -c "\l"

# 4. Check pg_hba.conf
docker compose exec postgres cat /etc/postgresql/pg_hba.conf

# 5. Recreate connection
docker compose restart n8n
```

### Database Performance Issues

```bash
# Check database size
docker compose exec postgres psql -U homelab_user -c "\l+"

# Check table sizes
docker compose exec postgres psql -U homelab_user -d homelab -c "\dt+"

# Check active connections
docker compose exec postgres psql -U homelab_user -c "SELECT count(*) FROM pg_stat_activity;"

# Solutions:
# 1. Vacuum database
docker compose exec postgres psql -U homelab_user -d homelab -c "VACUUM FULL;"

# 2. Analyze tables
docker compose exec postgres psql -U homelab_user -d homelab -c "ANALYZE;"

# 3. Increase shared buffers (if lots of RAM)
# In docker-compose.yml:
command: postgres -c shared_buffers=256MB
```

### Redis Connection Issues

```bash
# Test connection
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} PING

# Check memory usage
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} INFO memory

# Solutions:
# 1. Verify password
grep "REDIS_PASSWORD" .env

# 2. Check maxmemory
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} CONFIG GET maxmemory

# 3. Clear cache if full
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} FLUSHALL
```

---

## ⚡ Performance Issues

### High CPU Usage

**Diagnosis:**
```bash
# View container CPU usage
docker stats --no-stream

# Check top processes
docker compose exec jellyfin top

# View system load
uptime
```

**Solutions:**

```bash
# 1. Identify resource hog
docker stats --no-stream | sort -k3 -rh | head -5

# 2. Set CPU limits
# In docker-compose.yml:
deploy:
  resources:
    limits:
      cpus: '1.0'

# 3. Check for runaway processes
docker compose exec jellyfin ps aux | grep -v grep

# 4. Restart high-CPU service
docker compose restart jellyfin

# 5. Check for transcoding (Jellyfin)
# Dashboard → Playback → Active sessions
```

### High Memory Usage

**Diagnosis:**
```bash
# System memory
free -h

# Container memory
docker stats --no-stream | sort -k4 -rh | head -5

# Check for memory leaks
docker stats jellyfin
# Watch over time
```

**Solutions:**

```bash
# 1. Set memory limits
# In docker-compose.yml:
deploy:
  resources:
    limits:
      memory: 2G

# 2. Restart high-memory service
docker compose restart jellyfin

# 3. Check logs for memory errors
docker compose logs jellyfin | grep -i "memory\|oom"

# 4. Clear caches
docker compose exec jellyfin rm -rf /config/cache/*
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} FLUSHALL

# 5. Reduce concurrent operations
# Jellyfin: Limit simultaneous transcodes
# Sonarr: Reduce parallel downloads
```

### Slow Response Times

**Diagnosis:**
```bash
# Test response time
time curl -I http://localhost:7096

# Check network latency
docker compose exec heimdall ping jellyfin

# View Traefik metrics
curl http://localhost:7080/metrics | grep http_request_duration_seconds
```

**Solutions:**

```bash
# 1. Check database performance
# See Database section above

# 2. Enable caching (Redis)
# Ensure Redis is running and connected

# 3. Optimize media transcoding
# Jellyfin: Enable hardware acceleration
# Settings → Playback → Hardware Acceleration

# 4. Check disk I/O
iostat -x 1 5

# 5. Use SSD for configs
# Move config/ to SSD
```

### Disk I/O Issues

**Diagnosis:**
```bash
# Check disk usage
df -h

# Check I/O wait
iostat -x 1 5

# Find large files
du -sh config/* | sort -rh | head -10
```

**Solutions:**
```bash
# 1. Clean up disk space
docker system prune -a --volumes

# 2. Move logs off disk
# In docker-compose.yml:
logging:
  driver: "syslog"
  options:
    syslog-address: "tcp://remote-log-server:514"

# 3. Clean media transcodes
docker compose exec jellyfin rm -rf /config/transcodes/*

# 4. Optimize database
# See Database section

# 5. Move to faster storage
# Use SSD for Docker volumes
```

---

## 💾 Storage & Volume Issues

### Volume Permission Errors

**Symptoms:**
- "Permission denied" in logs
- Container won't start
- Can't read/write files

**Solutions:**

```bash
# 1. Check current permissions
ls -ld config/jellyfin/

# 2. Fix ownership
sudo chown -R $USER:$USER config/
sudo chown -R 1000:1000 config/  # PUID/PGID

# 3. Fix permissions
sudo chmod -R 755 config/

# 4. SELinux (if enabled)
sudo chcon -Rt container_file_t config/
```

### Volume Not Mounting

**Diagnosis:**
```bash
# Check mount points
docker compose exec jellyfin df -h

# Inspect volume
docker volume inspect homelab_postgres_data

# Check compose config
docker compose config | grep -A 5 "volumes:"
```

**Solutions:**

```bash
# 1. Verify path exists
ls -la config/jellyfin/

# 2. Check .env paths
grep "CONFIG_PATH" .env

# 3. Recreate volume
docker compose down
docker volume rm homelab_postgres_data
docker compose up -d

# 4. Fix Windows paths (WSL)
# Use forward slashes: ./config not .\config
```

### Out of Disk Space

**Diagnosis:**
```bash
# Check disk usage
df -h

# Find largest directories
du -sh /* | sort -rh | head -10
du -sh config/* | sort -rh | head -10

# Check Docker disk usage
docker system df
```

**Solutions:**

```bash
# 1. Clean Docker resources
docker system prune -a --volumes

# 2. Clean logs
docker compose logs > save_logs.txt
# Then restart services to truncate logs

# 3. Clean transcodes (Jellyfin)
docker compose exec jellyfin rm -rf /config/transcodes/*

# 4. Clean downloads (qBittorrent)
# Remove completed downloads

# 5. Move media to external drive
# Update MEDIA_PATH in .env
```

---

## 🖥️ Platform-Specific Issues

### Windows (WSL2)

#### Docker Desktop Not Starting
```bash
# Restart WSL
wsl --shutdown
# Start Docker Desktop again

# Update WSL
wsl --update

# Check WSL version
wsl --list --verbose
```

#### Path Issues
```bash
# Use forward slashes
CONFIG_PATH=./config  # ✓ Correct
CONFIG_PATH=.\config  # ✗ Wrong

# Windows paths in WSL
/mnt/c/Users/You/homelab  # Accesses C:\Users\You\homelab
```

#### Network Issues
```powershell
# Reset Docker network
docker network prune
# Restart Docker Desktop

# Reset WSL network
wsl --shutdown
netsh winsock reset
netsh int ip reset
```

### macOS

#### Docker Desktop Performance
```bash
# Allocate more resources
# Docker Desktop → Preferences → Resources
# CPU: 4+ cores
# Memory: 8+ GB
# Disk: 100+ GB

# Use VirtioFS for better I/O
# Docker Desktop → Preferences → General
# Enable VirtioFS
```

#### Permission Issues
```bash
# macOS specific permissions
sudo chown -R $(whoami):staff config/

# Grant Full Disk Access
# System Preferences → Security & Privacy → Privacy
# Full Disk Access → Add Docker
```

### Linux

#### systemd Issues
```bash
# Docker service not starting
sudo systemctl status docker
sudo systemctl start docker
sudo systemctl enable docker

# View service logs
sudo journalctl -u docker -n 50
```

#### SELinux Issues
```bash
# Check SELinux status
getenforce

# Temporarily disable
sudo setenforce 0

# Fix labels
sudo chcon -Rt container_file_t config/

# Permanently allow
sudo setsebool -P container_manage_cgroup on
```

---

## 🔬 Advanced Debugging

### Enable Debug Logging

```yaml
# In docker-compose.yml
services:
  traefik:
    command:
      - --log.level=DEBUG  # Change from INFO
      
  jellyfin:
    environment:
      - LOG_LEVEL=Debug
```

### Attach to Running Container

```bash
# Interactive shell
docker compose exec jellyfin /bin/bash

# Or with sh
docker compose exec jellyfin sh

# Run commands
ps aux
netstat -tulpn
cat /config/config.xml
```

### Network Debugging

```bash
# Install tools in container
docker compose exec jellyfin apt-get update
docker compose exec jellyfin apt-get install -y curl netcat dnsutils

# Test DNS
docker compose exec jellyfin nslookup postgres

# Test connectivity
docker compose exec jellyfin nc -zv postgres 5432

# Test HTTP
docker compose exec jellyfin curl -I http://traefik:8080
```

### Packet Capture

```bash
# Capture traffic on docker network
sudo tcpdump -i docker0 -w capture.pcap

# View captured packets
sudo tcpdump -r capture.pcap | head -50

# Filter by container IP
docker inspect jellyfin | grep IPAddress
sudo tcpdump -i docker0 host 172.18.0.5
```

### Trace System Calls

```bash
# Trace container
sudo strace -p $(docker inspect -f '{{.State.Pid}}' jellyfin)

# Trace specific system calls
sudo strace -e trace=open,read,write -p PID
```

### Generate Debug Report

```bash
# Create comprehensive debug report
cat > debug_report.txt << EOF
=== System Info ===
$(uname -a)
$(docker version)
$(docker compose version)

=== Service Status ===
$(docker compose ps)

=== Resource Usage ===
$(docker stats --no-stream)

=== Disk Usage ===
$(df -h)
$(docker system df)

=== Recent Logs ===
$(docker compose logs --tail=100)

=== Network Info ===
$(docker network ls)
$(docker network inspect traefik)

=== Configuration ===
$(docker compose config)
EOF

echo "Debug report saved to debug_report.txt"
```

---

## 🆘 Getting Help

### Before Asking for Help

Create a proper bug report:

```bash
# 1. Generate debug report
./scripts/generate-debug-report.sh

# 2. Gather relevant info
- What were you trying to do?
- What happened instead?
- What have you tried?
- Any error messages?
- Relevant logs

# 3. Sanitize sensitive data
# Remove passwords, tokens, domains from logs
```

### Where to Get Help

1. **Documentation**: Check all docs in `docs/` folder
2. **Search Issues**: [GitHub Issues](https://github.com/r-o-k-u/Homelab/issues)
3. **Create Issue**: [New Issue](https://github.com/r-o-k-u/Homelab/issues/new)
4. **Community**: r/selfhosted, Docker forums

### Include in Your Report

- Docker version
- OS and version
- docker-compose.yml (sanitized)
- .env (WITHOUT passwords)
- Service logs
- Error messages
- Steps to reproduce

---

## 📚 Related Documentation

- [Quick Start Guide](QUICKSTART.md)
- [Architecture Overview](ARCHITECTURE.md)
- [Operations Guide](OPERATIONS.md)
- [Networking Guide](NETWORKING.md)

---

[⬅ Back to Main README](../README.md)