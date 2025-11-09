# 🏛️ Architecture Overview

Deep dive into the homelab system design, network topology, data flows, and architectural decisions.

---

## 📑 Table of Contents

- [System Architecture](#-system-architecture)
- [Network Topology](#-network-topology)
- [Data Flow](#-data-flow)
- [Storage Architecture](#-storage-architecture)
- [Security Model](#-security-model)
- [Scalability & Performance](#-scalability--performance)
- [Design Decisions](#-design-decisions)

---

## 🏗️ System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ ports 80/443
                     │
         ┌───────────▼──────────┐
         │    Traefik Proxy     │  ◄── SSL Termination
         │  (Reverse Proxy)     │  ◄── Request Routing
         └───────────┬──────────┘  ◄── Service Discovery
                     │
        ┌────────────┴─────────────┐
        │                          │
   ┌────▼────┐              ┌─────▼──────┐
   │ traefik │              │  internal  │
   │ network │              │  network   │
   └────┬────┘              └─────┬──────┘
        │                         │
   ┌────┴─────────────────────────┴────┐
   │        Service Container Layer     │
   │  ┌─────────┐  ┌──────────┐       │
   │  │Jellyfin │  │Navidrome │  ...  │
   │  └─────────┘  └──────────┘       │
   └────────────────┬──────────────────┘
                    │
        ┌───────────┴──────────┐
        │                      │
   ┌────▼────┐          ┌─────▼─────┐
   │Database │          │  Volume   │
   │ Layer   │          │  Storage  │
   └─────────┘          └───────────┘
```

### Component Layers

#### 1. **Entry Layer**
- **Traefik Reverse Proxy**: Single point of entry
- **SSL/TLS Termination**: Automatic certificate management
- **Request Routing**: Dynamic service discovery via Docker labels

#### 2. **Application Layer**
Service categories:
- **Core Services**: Essential infrastructure (dashboard, search)
- **Media Services**: Streaming and automation (Jellyfin, Sonarr, Radarr)
- **Home Automation**: IoT and smart home (Home Assistant, Node-RED)
- **Development**: Code editors, ML tools (Jupyter, MLflow)
- **Productivity**: Knowledge management (KaraKeep, n8n)

#### 3. **Data Layer**
- **PostgreSQL**: Structured data (n8n workflows, Outline wiki)
- **Redis**: Caching and sessions
- **InfluxDB**: Time-series metrics
- **Meilisearch**: Full-text search indexing

#### 4. **Storage Layer**
- **Config Volumes**: Service configurations (persistent)
- **Media Volumes**: Content storage (movies, music, photos)
- **Backup Volumes**: Automated backups

---

## 🌐 Network Topology

### Network Segmentation

```
┌─────────────────────────────────────────────────────────────┐
│                     Docker Host                              │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              traefik (external network)              │   │
│  │  - Bridge network                                    │   │
│  │  - Connected to internet-facing services             │   │
│  │  - Services: Traefik, all web-accessible apps        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │          homelab_internal (internal network)         │   │
│  │  - Bridge network                                    │   │
│  │  - Backend services only                             │   │
│  │  - Services: Databases, Redis, Mosquitto, ROS        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Host Network (special)                  │   │
│  │  - Direct host network access                        │   │
│  │  - Services: Pi-hole (DNS port 53)                   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Network Design Principles

1. **Isolation**: Public-facing services on `traefik`, backends on `internal`
2. **Least Privilege**: Services only join networks they need
3. **Service Discovery**: Docker DNS for inter-service communication
4. **External Access**: Only Traefik exposes ports 80/443 externally

### Service Network Membership

| Service | traefik | internal | Purpose |
|---------|---------|----------|---------|
| **Traefik** | ✅ | ❌ | Entry point |
| **Heimdall** | ✅ | ✅ | Web UI + backend calls |
| **Jellyfin** | ✅ | ✅ | Web UI + database |
| **PostgreSQL** | ❌ | ✅ | Backend only |
| **Redis** | ❌ | ✅ | Backend only |
| **Mosquitto** | ❌ | ✅ | Backend only |
| **Home Assistant** | ✅ | ✅ | Web UI + IoT devices |

---

## 🔄 Data Flow

### Request Flow (Domain Mode)

```
1. User Request
   https://media.lab.yourdomain.com
           │
           ▼
2. DNS Resolution
   lab.yourdomain.com → [Your Server IP]
           │
           ▼
3. Traefik Entry (Port 443)
   - SSL Termination
   - Certificate validation
           │
           ▼
4. Route Matching
   - Check routing rules
   - Find matching service (Host: media.lab.yourdomain.com)
           │
           ▼
5. Backend Service
   - Forward to jellyfin:8096 (internal network)
   - Service processes request
           │
           ▼
6. Response
   - Jellyfin → Traefik → User
   - Encrypted via SSL
```

### Request Flow (Localhost Mode)

```
1. User Request
   http://localhost:7096
           │
           ▼
2. Direct Port Mapping
   localhost:7096 → jellyfin:8096
           │
           ▼
3. Service Response
   - No reverse proxy
   - Direct connection
   - No SSL
```

### Database Flow

```
Application (n8n)
       │
       │ Connection String:
       │ postgresql://postgres:5432/n8n
       │
       ▼
PostgreSQL Container
       │
       ├── Database: n8n
       ├── Database: outline  
       ├── Database: homelab
       │
       ▼
Volume: postgres/data
   (Persistent Storage)
```

### Media Flow

```
1. Media Request
   User → Jellyfin UI
           │
           ▼
2. Library Scan
   Jellyfin scans /data/movies
           │
           ▼
3. Volume Mount
   /data/movies → Host: media/movies
           │
           ▼
4. File Access
   Jellyfin reads video file
           │
           ▼
5. Transcoding (if needed)
   Convert format for streaming
           │
           ▼
6. Stream
   Video → User (HLS/DASH)
```

### Automation Flow (Media)

```
1. User adds show in Sonarr
           │
           ▼
2. Sonarr queries Prowlarr
   (Search for episodes)
           │
           ▼
3. Prowlarr searches indexers
   (Returns torrent/NZB links)
           │
           ▼
4. Sonarr sends to qBittorrent
   (Download client)
           │
           ▼
5. qBittorrent downloads
   Files saved to: /downloads
           │
           ▼
6. Sonarr monitors completion
   Moves files to: /tv/ShowName/Season
           │
           ▼
7. Jellyfin library scan
   New episode appears in UI
```

---

## 💾 Storage Architecture

### Volume Strategy

```
Host Filesystem
│
├── config/              (Service configurations)
│   ├── jellyfin/        → Jellyfin config & cache
│   ├── sonarr/          → Sonarr database & settings
│   ├── postgres/        → PostgreSQL data
│   └── [service]/       → Individual service data
│
├── media/               (Media content)
│   ├── movies/          → Radarr destination
│   ├── tv/              → Sonarr destination
│   ├── music/           → Lidarr destination
│   ├── photos/          → Photo storage
│   └── downloads/       → qBittorrent download folder
│
└── backups/             (Backup storage)
    └── [timestamp]/     → Timestamped backups
```

### Volume Binding Patterns

**Named Volumes** (for databases):
```yaml
volumes:
  postgres_data:
    driver: local
```
- Managed by Docker
- Better for databases
- Automatic garbage collection

**Bind Mounts** (for media):
```yaml
volumes:
  - ${MEDIA_PATH}/movies:/movies
```
- Direct host path mapping
- Easy file access from host
- Better for large media libraries

### Backup Strategy

```
Automated Backups
    │
    ├── Configuration Backup
    │   └── tar -czf config_backup.tar.gz config/
    │
    ├── Database Backup
    │   ├── PostgreSQL: pg_dumpall
    │   ├── Redis: RDB snapshot
    │   └── InfluxDB: influx backup
    │
    └── Metadata Backup
        ├── .env file
        └── docker-compose.yml
```

---

## 🔒 Security Model

### Defense in Depth

```
Layer 1: Network
├── Firewall (host level)
├── Docker network isolation
└── VPN for remote access (WireGuard)

Layer 2: Application
├── Traefik security headers
├── SSL/TLS encryption
└── Basic auth on sensitive services

Layer 3: Data
├── Database authentication
├── Redis password protection
└── Encrypted volumes (optional)

Layer 4: Access Control
├── Individual service authentication
├── User management per service
└── API key rotation
```

### Authentication Flow

```
External User
    │
    ▼
WireGuard VPN (optional)
    │
    ▼
Traefik
    │
    ├── SSL Certificate Validation
    ├── Rate Limiting (optional)
    └── Security Headers
    │
    ▼
Service (Jellyfin, Home Assistant, etc.)
    │
    ├── User Authentication
    ├── Session Management
    └── Authorization
    │
    ▼
Data Access
```

### Secrets Management

**Current Implementation:**
```env
# .env file
POSTGRES_PASSWORD=secure_password_here
REDIS_PASSWORD=secure_password_here
```

**Best Practices:**
1. Change all default passwords
2. Use strong, unique passwords (20+ characters)
3. Never commit .env to git
4. Use different passwords per service
5. Consider Docker secrets for production

**Future Enhancement:**
```yaml
# Using Docker secrets
secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
```

---

## 📈 Scalability & Performance

### Resource Allocation

**Minimum Requirements:**
```
Core Services:     512MB RAM
Monitoring Stack:  1GB RAM
Media Stack:       2GB RAM
Complete Stack:    8GB RAM
```

**Recommended Configuration:**
```
CPU:  4+ cores
RAM:  16GB
Disk: SSD for configs, HDD for media
```

### Performance Optimization

#### 1. **Container Resource Limits**
```yaml
services:
  jellyfin:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          memory: 1G
```

#### 2. **Caching Strategy**
- Redis for session data
- Traefik response caching
- Jellyfin transcoding cache

#### 3. **Database Optimization**
```sql
-- PostgreSQL tuning
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
```

#### 4. **Media Transcoding**
- Hardware acceleration (GPU)
- Preset quality profiles
- Direct play when possible

### Horizontal Scaling Considerations

**Current State:** Single-node deployment

**Future Scaling Options:**
1. **Docker Swarm**: Multi-node orchestration
2. **Load Balancing**: Multiple Traefik instances
3. **Database Replication**: PostgreSQL primary/replica
4. **Distributed Storage**: GlusterFS, Ceph

---

## 🎯 Design Decisions

### Why Docker Compose?

**Pros:**
✅ Simple, declarative configuration  
✅ Easy to understand and modify  
✅ Perfect for single-node deployments  
✅ Native Docker integration  
✅ No additional orchestration overhead  

**Cons:**
❌ No native high availability  
❌ Single point of failure  
❌ Manual scaling  

**Alternative Considered:** Kubernetes
- Rejected: Too complex for single-node homelab
- Overhead doesn't justify benefits at this scale

### Why Traefik?

**Pros:**
✅ Automatic service discovery  
✅ Native Docker integration  
✅ Automatic SSL with Let's Encrypt  
✅ Modern, actively maintained  
✅ Built-in middleware  

**Alternatives Considered:**
- **Nginx Proxy Manager**: Less flexible, GUI-focused
- **Caddy**: Good, but Traefik has better Docker integration
- **HAProxy**: More complex configuration

### Why PostgreSQL?

**Pros:**
✅ Mature, reliable  
✅ ACID compliance  
✅ Rich feature set  
✅ Wide application support  

**For Time-Series:** InfluxDB (purpose-built)  
**For Caching:** Redis (in-memory speed)  
**For Search:** Meilisearch (fast full-text)

### Profile-Based Architecture

**Decision:** Use Docker Compose profiles instead of multiple compose files

**Rationale:**
- Single source of truth
- Easy to combine profiles
- No file management complexity
- Clear service grouping

**Example:**
```bash
# Instead of:
docker-compose -f docker-compose.yml -f media.yml -f monitoring.yml up

# We use:
docker compose --profile media --profile monitoring up
```

### Network Design Choices

**Decision:** Two networks (traefik + internal)

**Rationale:**
- Security: Databases not exposed to internet-facing network
- Simplicity: Easy to understand
- Flexibility: Services can join both if needed

**Alternative Considered:** Single network
- Rejected: Less secure, no isolation

### Volume Mount Strategy

**Decision:** Mix of bind mounts (media) and named volumes (configs)

**Rationale:**
- **Bind Mounts for Media**: Easy host access, large files
- **Named Volumes for Configs**: Better for small, frequently accessed data
- **Docker-managed**: Automatic cleanup, portability

---

## 🔮 Future Architecture Considerations

### Potential Enhancements

1. **High Availability**
   - Docker Swarm for multi-node
   - Database replication
   - Shared storage (NFS/Ceph)

2. **Monitoring Enhancement**
   - Prometheus for metrics
   - Loki for log aggregation
   - AlertManager for notifications

3. **Security Hardening**
   - Vault for secrets management
   - LDAP/SSO for unified authentication
   - WAF (Web Application Firewall)

4. **Automation**
   - GitOps workflow (ArgoCD)
   - Automated testing
   - CI/CD pipeline

5. **Observability**
   - Distributed tracing (Jaeger)
   - APM (Application Performance Monitoring)
   - Real-user monitoring

---

## 📊 Architecture Metrics

### Current System Capabilities

| Metric | Value |
|--------|-------|
| **Services** | 30+ |
| **Networks** | 2 |
| **Volumes** | 40+ |
| **Profiles** | 12 |
| **Databases** | 3 types |
| **Entry Points** | 2 (80, 443) |
| **SSL Domains** | Unlimited (Let's Encrypt) |

### Performance Targets

| Service | Target Response Time | Uptime Goal |
|---------|---------------------|-------------|
| **Traefik** | < 50ms | 99.9% |
| **Jellyfin** | < 200ms (UI) | 99.5% |
| **Home Assistant** | < 100ms | 99.9% |
| **Database** | < 10ms (internal) | 99.9% |

---

## 📚 Related Documentation

- [Quick Start Guide](QUICKSTART.md) - Getting started
- [Networking Guide](NETWORKING.md) - Network configuration details
- [Operations Guide](OPERATIONS.md) - Managing the system
- [Service Catalog](SERVICES.md) - Individual service documentation

---

[⬅ Back to Main README](../README.md)