# 📚 Service Catalog

Complete reference for all services in the homelab stack, including configuration, access, and usage guidelines.

---

## 📑 Table of Contents

- [📚 Service Catalog](#-service-catalog)
  - [📑 Table of Contents](#-table-of-contents)
  - [🏗️ Core Infrastructure](#️-core-infrastructure)
    - [Traefik](#traefik)
    - [Heimdall](#heimdall)
    - [SearXNG](#searxng)
  - [📊 Monitoring \& Metrics](#-monitoring--metrics)
    - [Uptime Kuma](#uptime-kuma)
    - [InfluxDB](#influxdb)
    - [Grafana](#grafana)
  - [🏠 IoT \& Home Automation](#-iot--home-automation)
    - [Home Assistant](#home-assistant)
    - [Mosquitto](#mosquitto)
    - [Node-RED](#node-red)
    - [ESPHome](#esphome)
  - [🤖 Robotics \& Development](#-robotics--development)
    - [ROS Core](#ros-core)
    - [ROSBridge](#rosbridge)
    - [MLflow](#mlflow)
  - [📝 Productivity \& Tools](#-productivity--tools)
    - [KaraKeep](#karakeep)
    - [FileBrowser](#filebrowser)
  - [⚡ Automation \& Workflow](#-automation--workflow)
    - [n8n](#n8n)
  - [💾 Databases \& Cache](#-databases--cache)
    - [PostgreSQL](#postgresql)
    - [Redis](#redis)
  - [📂 File Services](#-file-services)
    - [Syncthing](#syncthing)
  - [🌐 Networking \& Security](#-networking--security)
    - [Pi-hole](#pi-hole)
    - [WireGuard](#wireguard)
  - [📺 Media Stack](#-media-stack)
    - [Jellyfin](#jellyfin)
    - [Sonarr](#sonarr)
    - [Radarr](#radarr)
  - [🎵 Music Services](#-music-services)
    - [Navidrome](#navidrome)
    - [Lidarr](#lidarr)

---

## 🏗️ Core Infrastructure

### Traefik
**Reverse Proxy & Load Balancer**

| Property | Value |
|----------|-------|
| **Image** | `traefik:v3.0` |
| **Profile** | `core` |
| **Ports** | 80, 443, 7080 (dashboard) |
| **Access** | `https://traefik.{DOMAIN}` or `http://localhost:7080` |
| **Purpose** | Automatic SSL, routing, load balancing |

**Configuration:**
```yaml
# Automatic features:
- SSL certificate management (Let's Encrypt)
- Service discovery via Docker labels
- Dashboard for monitoring routes
- Metrics export for Prometheus
```

**First Steps:**
1. Access dashboard: http://localhost:7080
2. Verify all routes appear under HTTP > Routers
3. Check certificate status (domain mode)

**Troubleshooting:**
```bash
# View routes
docker compose logs traefik | grep "Router"

# Check certificate status
docker compose logs traefik | grep "acme"

# Test routing
curl -I http://localhost
```

---

### Heimdall
**Application Dashboard**

| Property | Value |
|----------|-------|
| **Image** | `linuxserver/heimdall` |
| **Profile** | `core` |
| **Port** | 7081 |
| **Access** | `https://dashboard.{DOMAIN}` or `http://localhost:7081` |
| **Purpose** | Centralized dashboard for all services |

**Configuration:**
- **Location**: `config/heimdall/`
- **Customization**: Via web interface
- **Themes**: Multiple built-in themes

**First Steps:**
1. Add applications via "+" button
2. Configure app URLs (use internal names like `http://jellyfin:8096` in domain mode)
3. Upload custom icons (optional)
4. Organize with tags

---

### SearXNG
**Privacy-Focused Search Engine**

| Property | Value |
|----------|-------|
| **Image** | `searxng/searxng` |
| **Profile** | `core` |
| **Port** | 7082 |
| **Access** | `https://search.{DOMAIN}` or `http://localhost:7082` |
| **Purpose** | Private metasearch engine |

**Configuration:**
- **Location**: `config/searxng/settings.yml`
- **Secret Key**: Set via `SEARXNG_SECRET` in .env

**Features:**
- Aggregates results from 70+ search engines
- No tracking or logging
- Customizable search engines
- JSON/RSS/CSV output

**Customization:**
```yaml
# config/searxng/settings.yml
engines:
  - name: google
    weight: 1
  - name: duckduckgo
    weight: 1
```

---

## 📊 Monitoring & Metrics

### Uptime Kuma
**Service Monitoring**

| Property | Value |
|----------|-------|
| **Image** | `louislam/uptime-kuma` |
| **Profile** | `monitoring` |
| **Port** | 7001 |
| **Access** | `https://status.{DOMAIN}` or `http://localhost:7001` |
| **Purpose** | Monitor service uptime and performance |

**First Steps:**
1. Create admin account
2. Add monitors for each service
3. Configure notification methods
4. Set up status pages (optional)

**Monitor Types:**
- HTTP(s)
- TCP Port
- Ping
- DNS
- Docker Container

**Notifications:**
- Email, Telegram, Discord, Slack
- Webhook, Pushover, Signal
- SMS (via Twilio)

---

### InfluxDB
**Time-Series Database**

| Property | Value |
|----------|-------|
| **Image** | `influxdb:2.7` |
| **Profile** | `monitoring` |
| **Port** | 8086 |
| **Access** | `https://influxdb.{DOMAIN}` or `http://localhost:8086` |
| **Purpose** | Store metrics and time-series data |

**Configuration:**
- **Username**: Set via `INFLUXDB_USER`
- **Password**: Set via `INFLUXDB_PASSWORD`
- **Token**: Set via `INFLUXDB_TOKEN`
- **Org**: Set via `INFLUXDB_ORG`

**Usage:**
```bash
# Create bucket
docker compose exec influxdb influx bucket create -n sensors

# Query data
docker compose exec influxdb influx query 'from(bucket:"metrics") |> range(start: -1h)'
```

---

### Grafana
**Metrics Visualization**

| Property | Value |
|----------|-------|
| **Image** | `grafana/grafana` |
| **Profile** | `monitoring` |
| **Port** | 7300 |
| **Access** | `https://grafana.{DOMAIN}` or `http://localhost:7300` |
| **Purpose** | Create dashboards for metrics visualization |

**Configuration:**
- **Username**: Set via `GRAFANA_USER`
- **Password**: Set via `GRAFANA_PASSWORD`

**First Steps:**
1. Log in with credentials
2. Add InfluxDB as data source
3. Import community dashboards
4. Create custom dashboards

**Pre-installed Plugins:**
- Clock Panel
- Simple JSON
- Worldmap Panel

---

## 🏠 IoT & Home Automation

### Home Assistant
**Smart Home Hub**

| Property | Value |
|----------|-------|
| **Image** | `ghcr.io/home-assistant/home-assistant:stable` |
| **Profile** | `iot`, `automation` |
| **Port** | 8123 |
| **Access** | `https://home.{DOMAIN}` or `http://localhost:8123` |
| **Purpose** | Central control for all smart home devices |

**Features:**
- 2000+ integrations
- Automation engine
- Voice control (Alexa, Google, Siri)
- Mobile apps (iOS/Android)

**First Steps:**
1. Create account on first access
2. Set location and timezone
3. Discover devices
4. Install HACS (Home Assistant Community Store)
5. Configure integrations

**Popular Integrations:**
- Zigbee2MQTT / Z-Wave JS
- ESPHome
- MQTT
- NodeRED
- InfluxDB

---

### Mosquitto
**MQTT Broker**

| Property | Value |
|----------|-------|
| **Image** | `eclipse-mosquitto` |
| **Profile** | `iot`, `automation` |
| **Ports** | 1883 (MQTT), 9001 (WebSocket) |
| **Access** | `mqtt://{SERVER_IP}:1883` |
| **Purpose** | Message broker for IoT devices |

**Configuration:**
- **Location**: `config/mosquitto/config/mosquitto.conf`
- **Data**: `config/mosquitto/data/`
- **Logs**: `config/mosquitto/log/`

**Testing:**
```bash
# Subscribe to topic
mosquitto_sub -h localhost -t "test/topic"

# Publish message
mosquitto_pub -h localhost -t "test/topic" -m "Hello MQTT"
```

---

### Node-RED
**Flow-Based Programming**

| Property | Value |
|----------|-------|
| **Image** | `nodered/node-red` |
| **Profile** | `iot`, `automation` |
| **Port** | 7180 |
| **Access** | `https://flows.{DOMAIN}` or `http://localhost:7180` |
| **Purpose** | Visual programming for IoT automation |

**Features:**
- Visual flow editor
- 4000+ community nodes
- MQTT, HTTP, WebSocket support
- Dashboard UI builder

**First Steps:**
1. Access editor
2. Install palette nodes (Dashboard, Home Assistant)
3. Create simple flow
4. Deploy and test

**Common Nodes:**
- MQTT in/out
- HTTP request
- Function (JavaScript)
- Switch/Change
- Dashboard widgets

---

### ESPHome
**ESP Device Firmware**

| Property | Value |
|----------|-------|
| **Image** | `ghcr.io/esphome/esphome` |
| **Profile** | `iot` |
| **Port** | 7605 |
| **Access** | `https://esphome.{DOMAIN}` or `http://localhost:7605` |
| **Purpose** | Create firmware for ESP8266/ESP32 devices |

**Features:**
- No coding required (YAML config)
- OTA updates
- Native Home Assistant integration
- Web-based flashing

**First Steps:**
1. Create new device configuration
2. Configure sensors/outputs
3. Compile firmware
4. Flash device (USB or OTA)

---

## 🤖 Robotics & Development

### ROS Core
**Robot Operating System**

| Property | Value |
|----------|-------|
| **Image** | `ros:noetic-ros-core` |
| **Profile** | `robotics`, `development` |
| **Port** | 11311 |
| **Access** | Network only (no web UI) |
| **Purpose** | Core ROS master node |

**Usage:**
```bash
# List topics
docker compose exec ros-core rostopic list

# Echo topic
docker compose exec ros-core rostopic echo /topic_name

# Publish to topic
docker compose exec ros-core rostopic pub /test std_msgs/String "data: 'hello'"
```

---

### ROSBridge
**ROS WebSocket Bridge**

| Property | Value |
|----------|-------|
| **Image** | `ros:noetic-ros-base` |
| **Profile** | `robotics` |
| **Port** | 7909 (WebSocket) |
| **Access** | `ws://localhost:7909` or `wss://ros.{DOMAIN}` |
| **Purpose** | Connect web apps to ROS |

**Usage:**
```javascript
// Connect from JavaScript
const ros = new ROSLIB.Ros({
  url: 'ws://localhost:7909'
});

ros.on('connection', () => {
  console.log('Connected to ROS');
});
```

---

### MLflow
**ML Experiment Tracking**

| Property | Value |
|----------|-------|
| **Image** | `ghcr.io/mlflow/mlflow` |
| **Profile** | `ml`, `development` |
| **Port** | 7500 |
| **Access** | `https://ml.{DOMAIN}` or `http://localhost:7500` |
| **Purpose** | Track ML experiments and models |

**Features:**
- Experiment tracking
- Model registry
- Model deployment
- Metrics visualization

**Usage:**
```python
import mlflow

mlflow.set_tracking_uri("http://localhost:7500")
mlflow.set_experiment("my_experiment")

with mlflow.start_run():
    mlflow.log_param("param1", 5)
    mlflow.log_metric("accuracy", 0.95)
```

---

## 📝 Productivity & Tools

### KaraKeep
**AI-Powered Bookmark Manager**

| Property | Value |
|----------|-------|
| **Image** | `ghcr.io/karakeep-app/karakeep` |
| **Profile** | `productivity` |
| **Port** | 7301 |
| **Access** | `https://bookmarks.{DOMAIN}` or `http://localhost:7301` |
| **Purpose** | Intelligent bookmark and note management |

**Components:**
- **Web UI**: Main application
- **Meilisearch**: Fast full-text search
- **Chrome Headless**: Screenshot capture

**Features:**
- Automatic webpage archiving
- Full-text search
- Tags and organization
- Screenshot capture
- Browser extensions

---

### FileBrowser
**Web File Manager**

| Property | Value |
|----------|-------|
| **Image** | `filebrowser/filebrowser` |
| **Profile** | `files`, `productivity` |
| **Port** | 7805 |
| **Access** | `https://files.{DOMAIN}` or `http://localhost:7805` |
| **Purpose** | Web-based file management |

**Features:**
- Upload/download files
- Create/edit text files
- Share files (optional)
- User management
- Custom commands

**Default Credentials:**
- Username: `admin`
- Password: `admin`
- **CHANGE IMMEDIATELY**

---

## ⚡ Automation & Workflow

### n8n
**Workflow Automation**

| Property | Value |
|----------|-------|
| **Image** | `n8nio/n8n` |
| **Profile** | `automation`, `workflow` |
| **Port** | 7067 |
| **Access** | `https://n8n.{DOMAIN}` or `http://localhost:7067` |
| **Purpose** | Zapier/IFTTT alternative with 350+ integrations |

**Configuration:**
- **Username**: Set via `N8N_USER`
- **Password**: Set via `N8N_PASSWORD`
- **Database**: PostgreSQL (automatic)

**Features:**
- Visual workflow builder
- 350+ integrations
- Custom code nodes
- Webhook support
- Scheduled workflows

**Common Workflows:**
- Sync data between services
- Automated backups
- Social media automation
- Data processing pipelines

---

## 💾 Databases & Cache

### PostgreSQL
**Relational Database**

| Property | Value |
|----------|-------|
| **Image** | `postgres:15-alpine` |
| **Profile** | `databases` |
| **Port** | 5433 |
| **Access** | `postgresql://{SERVER_IP}:5433` |
| **Purpose** | Primary database for applications |

**Configuration:**
- **Database**: Set via `POSTGRES_DB`
- **User**: Set via `POSTGRES_USER`
- **Password**: Set via `POSTGRES_PASSWORD`

**Pre-created Databases:**
- `homelab` (main)
- `n8n`
- `outline`

**Usage:**
```bash
# Connect
docker compose exec postgres psql -U homelab_user -d homelab

# List databases
docker compose exec postgres psql -U homelab_user -c '\l'

# Backup
docker compose exec postgres pg_dump -U homelab_user homelab > backup.sql
```

---

### Redis
**In-Memory Cache**

| Property | Value |
|----------|-------|
| **Image** | `redis:7-alpine` |
| **Profile** | `databases` |
| **Port** | 6380 |
| **Access** | `redis://:{PASSWORD}@{SERVER_IP}:6380` |
| **Purpose** | Caching and session storage |

**Configuration:**
- **Password**: Set via `REDIS_PASSWORD`
- **Max Memory**: 512MB
- **Eviction**: allkeys-lru

**Usage:**
```bash
# Connect
docker compose exec redis redis-cli -a {REDIS_PASSWORD}

# Check status
docker compose exec redis redis-cli -a {REDIS_PASSWORD} INFO
```

---

## 📂 File Services

### Syncthing
**File Synchronization**

| Property | Value |
|----------|-------|
| **Image** | `linuxserver/syncthing` |
| **Profile** | `files`, `backup` |
| **Ports** | 8384 (UI), 22000 (transfer), 21027 (discovery) |
| **Access** | `https://sync.{DOMAIN}` or `http://localhost:8384` |
| **Purpose** | Continuous file synchronization |

**Features:**
- P2P synchronization
- Versioning
- Ignore patterns
- Encrypted transfers

**First Steps:**
1. Access web UI
2. Add remote device
3. Share folder
4. Configure sync options

---

## 🌐 Networking & Security

### Pi-hole
**Network-Wide Ad Blocker**

| Property | Value |
|----------|-------|
| **Image** | `pihole/pihole` |
| **Profile** | `networking` |
| **Ports** | 53 (DNS), 8084 (Web) |
| **Access** | `https://pihole.{DOMAIN}` or `http://localhost:8084` |
| **Purpose** | DNS-based ad blocking |

**Configuration:**
- **Password**: Set via `PIHOLE_PASSWORD`
- **DNS**: Set via `DNS_PRIMARY`, `DNS_SECONDARY`

**First Steps:**
1. Log in to admin panel
2. Update gravity (ad lists)
3. Configure router to use Pi-hole as DNS
4. Add custom block lists (optional)

**Features:**
- Block ads network-wide
- Local DNS records
- DHCP server (optional)
- Query logging

---

### WireGuard
**VPN Server**

| Property | Value |
|----------|-------|
| **Image** | `ghcr.io/wg-easy/wg-easy` |
| **Profile** | `networking` |
| **Ports** | 51820 (VPN), 7518 (UI) |
| **Access** | `https://vpn.{DOMAIN}` or `http://localhost:7518` |
| **Purpose** | Secure remote access to homelab |

**Configuration:**
- **Host**: Set via `HOMELAB_SERVER_IP`
- **Password**: Set via `WG_UI_PASSWORD_HASH`

**First Steps:**
1. Access web UI
2. Create client configuration
3. Scan QR code with mobile app
4. Test connection

---

## 📺 Media Stack

### Jellyfin
**Media Server**

| Property | Value |
|----------|-------|
| **Image** | `linuxserver/jellyfin` |
| **Profile** | `media` |
| **Port** | 7096 |
| **Access** | `https://media.{DOMAIN}` or `http://localhost:7096` |
| **Purpose** | Stream movies, TV shows, music, photos |

**Features:**
- Hardware transcoding
- Mobile apps
- Live TV & DVR
- Sync to mobile

**First Steps:**
1. Create admin account
2. Add libraries
3. Configure metadata providers
4. Set up users

---

### Sonarr
**TV Show Automation**

| Property | Value |
|----------|-------|
| **Image** | `linuxserver/sonarr` |
| **Profile** | `media` |
| **Port** | 8989 |
| **Purpose** | Automatically download TV shows |

---

### Radarr
**Movie Automation**

| Property | Value |
|----------|-------|
| **Image** | `linuxserver/radarr` |
| **Profile** | `media` |
| **Port** | 7878 |
| **Purpose** | Automatically download movies |

---

## 🎵 Music Services

### Navidrome
**Music Streaming Server**

| Property | Value |
|----------|-------|
| **Image** | `deluan/navidrome` |
| **Profile** | `music` |
| **Port** | 7453 |
| **Access** | `https://music.{DOMAIN}` or `http://localhost:7453` |
| **Purpose** | Personal Spotify alternative |

**Features:**
- Subsonic API compatible
- Mobile apps support
- Transcoding
- Playlists and favorites
- Scrobbling (Last.fm)

---

### Lidarr
**Music Collection Manager**

| Property | Value |
|----------|-------|
| **Image** | `linuxserver/lidarr` |
| **Profile** | `music` |
| **Port** | 8686 |
| **Purpose** | Automatically download music |

---

[⬅ Back to Main README](../README.md)