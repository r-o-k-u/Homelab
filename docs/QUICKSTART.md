# 🚀 Quick Start Guide

Get your homelab running in 10 minutes! This guide walks you through the fastest path to a working system.

---

## ⏱️ Time Requirements

| Setup Type | Time Needed | Complexity |
|------------|-------------|------------|
| **Minimal (Core)** | 10 minutes | Beginner |
| **Media Center** | 20 minutes | Intermediate |
| **Full Stack** | 30-45 minutes | Advanced |

---

## 📋 Prerequisites Checklist

### Required
- [ ] **Docker Desktop** installed and running
  - [Windows](https://docs.docker.com/desktop/install/windows-install/)
  - [macOS](https://docs.docker.com/desktop/install/mac-install/)
  - [Linux](https://docs.docker.com/engine/install/)
- [ ] **4GB RAM** available (8GB for full stack)
- [ ] **20GB free disk space** (more for media)
- [ ] **Git** installed (to clone the repository)

### Optional (for Domain Mode)
- [ ] Domain name (e.g., `yourdomain.com`)
- [ ] DNS access to create A records
- [ ] Router access for port forwarding

### Verification
```bash
# Check Docker
docker --version
docker compose version

# Check resources
docker info | grep "Total Memory"
df -h .  # Check disk space
```

---

## 🎯 Choose Your Path

### Path A: Minimal Setup (Recommended for First Time)
**Services:** Dashboard, Search Engine  
**Time:** 10 minutes  
**RAM:** 512MB  
**Best for:** Learning the system

### Path B: Media Center
**Services:** Core + Jellyfin + Navidrome + Media automation  
**Time:** 20 minutes  
**RAM:** 3GB  
**Best for:** Personal media streaming

### Path C: Complete Homelab
**Services:** Everything  
**Time:** 45 minutes  
**RAM:** 8GB+  
**Best for:** Power users

---

## 📥 Step 1: Get the Code

### Option A: Git Clone (Recommended)
```bash
# Create directory
mkdir -p ~/homelab
cd ~/homelab

# Clone repository
git clone https://github.com/yourusername/homelab.git .

# Verify
ls -la
```

### Option B: Download ZIP
1. Visit: https://github.com/yourusername/homelab
2. Click "Code" → "Download ZIP"
3. Extract to `~/homelab`

---

## ⚙️ Step 2: Configure Environment

### Create Configuration File
```bash
# Copy template
cp .env.example .env

# Edit configuration
nano .env  # or use your preferred editor
```

### Essential Settings

#### For Localhost Mode (Testing/Development)
```env
# Access Configuration
HOMELAB_DOMAIN=localhost
ACCESS_MODE=localhost

# Paths (Windows users: use forward slashes)
CONFIG_PATH=./config
MEDIA_PATH=./media
BACKUP_PATH=./backups

# Server Info
HOMELAB_SERVER_IP=192.168.1.100  # Your machine's IP

# Timezone
TZ=Africa/Nairobi
```

#### For Domain Mode (Production)
```env
# Access Configuration
HOMELAB_DOMAIN=lab.yourdomain.com
ACCESS_MODE=domain

# Traefik SSL
TRAEFIK_EMAIL=you@email.com

# Paths
CONFIG_PATH=./config
MEDIA_PATH=./media
BACKUP_PATH=./backups

# Server Info
HOMELAB_SERVER_IP=your.public.ip

# Timezone
TZ=Africa/Nairobi
```

### 🔐 Change ALL Passwords
```env
# Database Passwords
POSTGRES_PASSWORD=your_secure_postgres_password_here
REDIS_PASSWORD=your_secure_redis_password_here

# Service Passwords
PIHOLE_PASSWORD=your_secure_pihole_password_here
N8N_PASSWORD=your_secure_n8n_password_here
GRAFANA_PASSWORD=your_secure_grafana_password_here

# Tokens & Secrets
INFLUXDB_TOKEN=generate_random_token_here
SEARXNG_SECRET=generate_random_secret_here
```

> 💡 **Tip**: Generate secure passwords with:
> ```bash
> openssl rand -base64 32
> ```

---

## 🏗️ Step 3: Run Setup

### Automatic Setup (Recommended)
```bash
# Make script executable
chmod +x setup.sh

# Run setup
./setup.sh
```

**The script will:**
1. ✅ Check prerequisites (Docker, Compose)
2. ✅ Validate configuration file
3. ✅ Create directory structure
4. ✅ Set up Docker networks
5. ✅ Generate service configs
6. ✅ Show deployment menu

### Manual Setup (If script fails)
```bash
# Create Traefik network
docker network create traefik

# Create directories
mkdir -p config/{traefik/letsencrypt,heimdall,searxng,jellyfin,navidrome}
mkdir -p media/{movies,tv,music,photos}
mkdir -p backups

# Set permissions
chmod 755 config media backups
```

---

## 🚢 Step 4: Deploy Services

### Path A: Minimal Setup
```bash
# Deploy core services only
docker compose --profile core up -d

# Verify deployment
docker compose ps
```

**Access:**
- Dashboard: http://localhost:7081
- Search: http://localhost:7082

### Path B: Media Center
```bash
# Deploy core + media services
docker compose --profile core --profile media --profile music up -d

# Verify deployment
docker compose ps

# Check logs
docker compose logs -f jellyfin
```

**Access:**
- Dashboard: http://localhost:7081
- Jellyfin: http://localhost:7096
- Navidrome: http://localhost:7453
- Sonarr: http://localhost:8989
- Radarr: http://localhost:7878

### Path C: Complete Homelab
```bash
# Deploy everything
docker compose --profile all up -d

# This will take several minutes
# Watch progress
docker compose logs -f
```

**Access:** See [Service Catalog](SERVICES.md) for complete list

---

## ✅ Step 5: Verify Installation

### Quick Health Check
```bash
# Run health check script
./scripts/health-check.sh

# Manual verification
docker compose ps
docker stats --no-stream
```

### Expected Output
```
NAME                STATUS              PORTS
traefik            Up (healthy)        80/tcp, 443/tcp
heimdall           Up (healthy)        7081/tcp
searxng            Up (healthy)        7082/tcp
jellyfin           Up (healthy)        7096/tcp
...
```

### Access Your Services

#### Localhost Mode
1. Open browser
2. Navigate to: http://localhost:7081
3. You'll see your Heimdall dashboard
4. Click on service icons to access them

#### Domain Mode
1. Ensure DNS is configured
2. Navigate to: https://dashboard.lab.yourdomain.com
3. First access may take 1-2 minutes for SSL certificate generation

---

## 🎨 Step 6: Initial Configuration

### 1. Heimdall Dashboard
```
URL: http://localhost:7081 (or your domain)

Tasks:
- Add application tiles for your services
- Customize colors and layout
- Set homepage preferences
```

### 2. Jellyfin Media Server
```
URL: http://localhost:7096

First Run:
1. Create admin account
2. Add media libraries:
   - Movies: /data/movies
   - TV Shows: /data/tvshows
   - Music: /data/music
3. Configure metadata providers
4. Start initial scan
```

### 3. Navidrome Music Server
```
URL: http://localhost:7453

First Run:
1. Create admin account
2. Scan music library
3. Configure transcoding (optional)
```

### 4. Home Assistant (if deployed)
```
URL: http://localhost:8123

First Run:
1. Create admin account
2. Set location and timezone
3. Discover devices
4. Install integrations (HACS recommended)
```

### 5. Pi-hole (if deployed)
```
URL: http://localhost:8084/admin
Password: Check .env file

First Run:
1. Log in with password from .env
2. Update gravity
3. Configure DNS settings on your router
4. Enable DNSSEC (optional)
```

---

## 🔧 Post-Installation Tasks

### 1. Configure Media Automation (if deployed)

#### Prowlarr (Indexer Manager)
```
URL: http://localhost:9696

Steps:
1. Add indexers (torrent/NZB sites)
2. Configure API keys
3. Sync with Sonarr/Radarr/Lidarr
```

#### Sonarr (TV Shows)
```
URL: http://localhost:8989

Steps:
1. Connect to Prowlarr
2. Add download client (qBittorrent)
3. Add root folder: /tv
4. Configure quality profiles
```

#### Radarr (Movies)
```
URL: http://localhost:7878

Steps:
1. Connect to Prowlarr
2. Add download client (qBittorrent)
3. Add root folder: /movies
4. Configure quality profiles
```

### 2. Set Up Monitoring

#### Uptime Kuma
```
URL: http://localhost:7001

Steps:
1. Create admin account
2. Add monitors for each service
3. Configure notifications (Email, Discord, etc.)
4. Set check intervals
```

### 3. Configure Backups
```bash
# Test backup script
./scripts/backup.sh

# View backup
ls -lh backups/

# Schedule automatic backups (Linux/macOS)
crontab -e
# Add: 0 2 * * * cd /path/to/homelab && ./scripts/backup.sh
```

---

## 📊 Verification Checklist

After setup, verify:

- [ ] All services show "Up (healthy)" status
- [ ] Can access Heimdall dashboard
- [ ] Can access at least one media service
- [ ] No port conflicts (check docker compose ps)
- [ ] Traefik dashboard accessible (domain mode)
- [ ] SSL certificates generated (domain mode)
- [ ] Can log into each service with credentials
- [ ] Health check script runs without errors
- [ ] Backup script creates backup successfully

---

## 🆘 Common First-Time Issues

### Issue: Port Already in Use
```bash
# Find what's using the port
netstat -tulpn | grep :PORT  # Linux
lsof -i :PORT  # macOS
netstat -ano | findstr :PORT  # Windows

# Solution: Change port in .env
JELLYFIN_PORT=9096  # Instead of 7096
```

### Issue: Services Won't Start
```bash
# Check logs
docker compose logs jellyfin

# Common causes:
# 1. Not enough RAM
docker stats --no-stream

# 2. Permission issues
sudo chown -R $USER:$USER config/ media/

# 3. Docker not running
docker info
```

### Issue: Can't Access Services
```bash
# Verify services are running
docker compose ps

# Check network
docker network ls
docker network inspect traefik

# Test local access
curl http://localhost:7081
```

### Issue: SSL Certificates Not Generating (Domain Mode)
```bash
# Check Traefik logs
docker compose logs traefik

# Verify DNS
nslookup dashboard.lab.yourdomain.com

# Check port forwarding
# Ensure ports 80 and 443 are forwarded to your server
```

---

## 🎓 Next Steps

Now that you're running:

1. **📚 Read Documentation**
   - [Architecture Overview](ARCHITECTURE.md)
   - [Service Catalog](SERVICES.md)
   - [Operations Guide](OPERATIONS.md)

2. **🔐 Harden Security**
   - Review [Networking Guide](NETWORKING.md)
   - Set up WireGuard VPN
   - Configure Pi-hole

3. **📺 Set Up Media**
   - Add content to media folders
   - Configure quality profiles
   - Set up automation rules

4. **🏠 Configure Smart Home**
   - Connect IoT devices
   - Create automations in Home Assistant
   - Set up Node-RED flows

5. **📊 Monitor Everything**
   - Set up Uptime Kuma alerts
   - Configure Grafana dashboards
   - Enable InfluxDB metrics

---

## 💡 Pro Tips

1. **Start Small**: Begin with core profile, add services as needed
2. **Test Locally First**: Use localhost mode before domain mode
3. **Read Logs**: Most issues are obvious in logs
4. **Backup Regularly**: Run backup script weekly minimum
5. **Update Safely**: Pull updates during low-usage times
6. **Document Changes**: Keep notes of customizations
7. **Join Community**: Ask questions, share experiences

---

## 🎉 Congratulations!

You now have a working homelab! Take time to:
- Explore each service
- Customize to your needs
- Experiment with automation
- Share your setup with the community

---

**Need Help?** Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) or [open an issue](https://github.com/yourusername/homelab/issues).

[⬅ Back to Main README](../README.md)