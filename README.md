# 🏠 Homelab Docker Stack

[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-v3-2496ED?logo=docker)](https://docs.docker.com/compose/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> A production-ready, modular homelab infrastructure featuring 30+ self-hosted services including media streaming, home automation, IoT, robotics development, AI/ML tools, and enterprise-grade monitoring—all managed through Docker Compose with intelligent profile-based deployment.

## ✨ What Makes This Different

- **🎯 Smart Profile System**: Deploy exactly what you need—from minimal core services to complete production stacks
- **🌐 Dual Access Modes**: Switch seamlessly between domain-based (production) and localhost (development) deployments
- **🔄 Cross-Platform**: Single codebase runs on Linux, macOS, and Windows (WSL2/Git Bash)
- **🛡️ Production-Ready**: Built-in SSL, monitoring, backups, and health checks from day one
- **🧩 Truly Modular**: Mix and match service profiles without conflicts
- **📊 Infrastructure as Code**: Everything versioned and reproducible

---

## 📑 Documentation Index

| Document | Purpose | Audience |
|----------|---------|----------|
| **[Quick Start Guide](docs/QUICKSTART.md)** | Get running in 10 minutes | Everyone |
| **[Architecture Overview](docs/ARCHITECTURE.md)** | System design and decisions | Technical users |
| **[Service Catalog](docs/SERVICES.md)** | Complete service reference | All users |
| **[Network & Security](docs/NETWORKING.md)** | Traefik, SSL, VPN setup | Administrators |
| **[Operations Guide](docs/OPERATIONS.md)** | Day-to-day management | Operators |
| **[Troubleshooting](docs/TROUBLESHOOTING.md)** | Common issues & solutions | Support |
| **[Development Guide](docs/DEVELOPMENT.md)** | Contributing & customization | Developers |

---

## 🚀 Quick Start

### Prerequisites
- **Docker Desktop** (Windows/macOS) or **Docker Engine** (Linux) with Compose v2+
- **4GB RAM minimum** (8GB recommended for full stack)
- **20GB disk space** (more for media services)
- **Domain name** (optional, for production SSL)

### Installation (3 Steps)

```bash
# 1. Clone and navigate
git clone https://github.com/yourusername/homelab.git
cd homelab

# 2. Configure your environment
cp .env.example .env
nano .env  # Edit with your settings

# 3. Run setup and deploy
./setup.sh
```

**That's it!** The setup script will:
- ✅ Detect your OS and configure paths
- ✅ Create all necessary directories
- ✅ Set up Docker networks
- ✅ Generate service configurations
- ✅ Deploy your selected services

---

## 🎯 Deployment Profiles

Deploy exactly what you need with our profile system:

### 🔷 Core Profiles

| Profile | Services | Use Case | RAM |
|---------|----------|----------|-----|
| **core** | Traefik, Heimdall, SearXNG | Minimal dashboard + reverse proxy | 512MB |
| **monitoring** | Uptime Kuma, InfluxDB, Grafana | System health & metrics | 1GB |
| **databases** | PostgreSQL, Redis, TimescaleDB | Data layer for other services | 1GB |
| **networking** | Pi-hole, WireGuard | Network management + VPN | 512MB |

### 🟢 Application Profiles

| Profile | Services | Use Case | RAM |
|---------|----------|----------|-----|
| **media** | Jellyfin, Sonarr, Radarr, Prowlarr, qBittorrent | Complete media automation | 2GB |
| **music** | Navidrome, Lidarr | Music streaming & management | 512MB |
| **iot** | Home Assistant, Mosquitto, Node-RED, ESPHome | Smart home & IoT automation | 1GB |
| **productivity** | KaraKeep, Filebrowser, n8n | Knowledge & workflow management | 1GB |
| **robotics** | ROS Core, ROSBridge, MLflow | Robot development & ML | 2GB |

### 🔵 Special Profiles

| Profile | Description |
|---------|-------------|
| **all** | Deploy the complete stack (requires 8GB+ RAM) |
| **files** | File sync and management (Syncthing, Filebrowser) |
| **development** | Jupyter, Code-Server, OpenCV |

### Deployment Examples

```bash
# Minimal setup (dashboard + search)
docker compose --profile core up -d

# Media center
docker compose --profile core --profile media --profile music up -d

# Smart home + monitoring
docker compose --profile core --profile iot --profile monitoring up -d

# Complete production stack
docker compose --profile all up -d

# Stop specific profiles
docker compose --profile media down
```

---

## 🌐 Access Modes

### 🔐 Domain Mode (Production)
**Best for**: External access, SSL encryption, professional setup

```env
# .env configuration
HOMELAB_DOMAIN=lab.yourdomain.com
ACCESS_MODE=domain
TRAEFIK_EMAIL=you@email.com
```

**Features:**
- ✅ Automatic SSL with Let's Encrypt
- ✅ Clean URLs: `https://media.lab.yourdomain.com`
- ✅ Single entry point (ports 80/443)
- ✅ Production security

**Access:** `https://service.lab.yourdomain.com`

### 💻 Localhost Mode (Development)
**Best for**: Local testing, offline work, development

```env
# .env configuration
HOMELAB_DOMAIN=localhost
ACCESS_MODE=localhost
```

**Features:**
- ✅ No domain required
- ✅ Direct port access
- ✅ Works offline
- ✅ Simpler setup

**Access:** `http://localhost:PORT`

---

## 📊 Service Quick Reference

### Essential Services

| Service | Domain Mode | Localhost Mode | Default Credentials |
|---------|-------------|----------------|---------------------|
| **Dashboard** | `dashboard.lab` | `localhost:7081` | N/A |
| **Jellyfin** | `media.lab` | `localhost:7096` | Create on first run |
| **Navidrome** | `music.lab` | `localhost:7453` | Create on first run |
| **Home Assistant** | `home.lab` | `localhost:8123` | Create on first run |
| **Pi-hole** | `pihole.lab` | `localhost:8084` | See `.env` |
| **n8n** | `n8n.lab` | `localhost:7067` | See `.env` |
| **Uptime Kuma** | `status.lab` | `localhost:7001` | Create on first run |

> 🔑 **Security First**: All default passwords are in `.env` - **CHANGE THEM IMMEDIATELY**

---

## 🛠️ Essential Commands

### Service Management
```bash
# View running services
docker compose ps

# Start specific profiles
docker compose --profile media up -d

# Stop all services
docker compose down

# Restart a service
docker compose restart jellyfin

# View logs
docker compose logs -f sonarr
docker compose logs --tail=100 traefik

# Update services
docker compose pull
docker compose up -d
```

### Maintenance
```bash
# Health check
./scripts/health-check.sh

# Create backup
./scripts/backup.sh

# View resource usage
docker stats

# Clean unused resources
docker system prune -a --volumes
```

### Troubleshooting
```bash
# Check service health
docker compose ps
docker inspect jellyfin | grep -A 5 Health

# Network debugging
docker network inspect traefik
docker network inspect homelab_internal

# View Traefik routes (domain mode)
curl http://localhost:7080/api/http/routers

# Database connection test
docker compose exec postgres psql -U homelab_user -d homelab -c '\l'
```

---

## 📁 Project Structure

```
homelab/
├── docker-compose.yml          # Main service definitions
├── .env                        # Your configuration (EDIT THIS!)
├── .env.example                # Configuration template
├── setup.sh                    # Universal setup script
│
├── scripts/
│   ├── backup.sh              # Automated backup
│   ├── health-check.sh        # System health monitoring
│   ├── init-databases.sh      # Database initialization
│   └── pg_hba.conf            # PostgreSQL access rules
│
├── docs/
│   ├── QUICKSTART.md          # Getting started guide
│   ├── ARCHITECTURE.md        # System design
│   ├── SERVICES.md            # Service documentation
│   ├── NETWORKING.md          # Network configuration
│   ├── OPERATIONS.md          # Daily operations
│   ├── TROUBLESHOOTING.md     # Common issues
│   └── DEVELOPMENT.md         # Contributing guide
│
├── config/                     # Service configurations (auto-created)
│   ├── traefik/
│   ├── jellyfin/
│   ├── homeassistant/
│   └── [service-name]/
│
├── media/                      # Media library (auto-created)
│   ├── movies/
│   ├── tv/
│   ├── music/
│   └── photos/
│
└── backups/                    # Backup storage (auto-created)
    └── [timestamp]/
```

---

## 🔒 Security Checklist

Before going to production, ensure you've:

- [ ] Changed ALL default passwords in `.env`
- [ ] Configured firewall rules (only expose 80/443 if using domain mode)
- [ ] Set up WireGuard VPN for remote access
- [ ] Enabled Pi-hole for network-wide ad blocking
- [ ] Configured automated backups
- [ ] Set up Uptime Kuma monitoring
- [ ] Reviewed Traefik security headers (domain mode)
- [ ] Enabled fail2ban or similar (optional)
- [ ] Documented your configuration

---

## 🆘 Getting Help

### Common Issues
Check **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** for:
- Port conflicts
- SSL certificate problems
- Service startup failures
- Performance issues
- Network connectivity

### Support Channels
1. **Search existing issues**: [GitHub Issues](https://github.com/yourusername/homelab/issues)
2. **Documentation**: Check the `docs/` directory
3. **Health check**: Run `./scripts/health-check.sh`
4. **Create an issue**: Include logs and `.env` (WITHOUT passwords!)

### Reporting Bugs
```bash
# Generate diagnostic report
docker compose ps > diagnostic.txt
docker compose logs --tail=100 >> diagnostic.txt
./scripts/health-check.sh >> diagnostic.txt
```

---

## 🎯 Next Steps

After initial setup:

1. **📚 Read the Docs**: Start with [QUICKSTART.md](docs/QUICKSTART.md)
2. **🔐 Secure Your Stack**: Follow [NETWORKING.md](docs/NETWORKING.md)
3. **📊 Set Up Monitoring**: Configure Uptime Kuma and InfluxDB
4. **💾 Configure Backups**: Schedule automated backups
5. **🎨 Customize Heimdall**: Add your services to the dashboard
6. **🏠 Configure Home Assistant**: Set up your smart home devices
7. **📺 Set Up Media**: Configure Jellyfin, Sonarr, and Radarr

---

## 🤝 Contributing

We welcome contributions! See **[DEVELOPMENT.md](docs/DEVELOPMENT.md)** for:
- Development setup
- Code style guidelines
- Adding new services
- Testing procedures
- Submitting pull requests

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

This homelab stack is built on the shoulders of giants:

- **Docker** - Containerization platform
- **Traefik** - Modern reverse proxy
- **LinuxServer.io** - Excellent container images
- All the amazing open-source projects that make this possible

---

## 📊 Project Stats

- **30+ Services** ready to deploy
- **12 Service Profiles** for modular deployment
- **3 Platforms** supported (Linux, macOS, Windows)
- **2 Access Modes** for flexibility
- **1 Command** to get started

---

<div align="center">

**Built with ❤️ for the self-hosting community**

[⬆ Back to Top](#-homelab-docker-stack)

</div>