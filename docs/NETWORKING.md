# 🌐 Networking & Security Guide

Complete guide to network configuration, SSL setup, VPN access, and security hardening for your homelab.

---

## 📑 Table of Contents

- [Network Configuration](#-network-configuration)
- [Traefik Setup](#-traefik-setup)
- [SSL Certificates](#-ssl-certificates)
- [DNS Configuration](#-dns-configuration)
- [VPN Access (WireGuard)](#-vpn-access-wireguard)
- [Pi-hole Setup](#️-pi-hole-setup)
- [Security Hardening](#-security-hardening)
- [Firewall Configuration](#-firewall-configuration)
- [Troubleshooting](#-troubleshooting)

---

## 🔧 Network Configuration

### Prerequisites

Before configuring networking:
- [ ] Static IP address for your server
- [ ] Router admin access
- [ ] Domain name (for SSL)
- [ ] Basic understanding of port forwarding

### Network Architecture

```
Internet
    │
    │ ISP Router
    │
    ▼
[Your Router/Firewall]
    │
    │ Port Forwarding:
    │ 80 → Server:80
    │ 443 → Server:443
    │ 51820 → Server:51820 (VPN)
    │
    ▼
[Homelab Server]
    │
    ├── Docker Network: traefik (external)
    │   └── Accessible services
    │
    └── Docker Network: homelab_internal
        └── Backend services
```

### Get Your Server's IP Address

**Linux/macOS:**
```bash
ip addr show | grep "inet " | grep -v 127.0.0.1
# or
hostname -I
```

**Windows:**
```powershell
ipconfig | findstr IPv4
```

**Expected Output:** `192.168.x.x` (private network)

### Set Static IP

**Method 1: Router (Recommended)**
1. Log into router admin panel
2. Find DHCP settings
3. Reserve IP for server's MAC address
4. Note the assigned IP

**Method 2: Server Configuration**

**Ubuntu/Debian:**
```bash
# Edit netplan configuration
sudo nano /etc/netplan/01-netcfg.yaml
```

```yaml
network:
  version: 2
  ethernets:
    eth0:  # Or your interface name
      dhcp4: no
      addresses:
        - 192.168.1.100/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [1.1.1.1, 1.0.0.1]
```

```bash
sudo netplan apply
```

---

## 🚦 Traefik Setup

### Understanding Traefik

Traefik is a modern reverse proxy that:
- Routes requests to correct services
- Manages SSL certificates automatically
- Provides service discovery
- Offers monitoring dashboard

### Configuration Overview

Traefik is configured through three methods:
1. **Command Args** (in docker-compose.yml)
2. **Docker Labels** (on each service)
3. **Dynamic Config** (optional files)

### Command Configuration

Located in `docker-compose.yml`:

```yaml
traefik:
  command:
    # Enable dashboard
    - --api.dashboard=true
    - --api.insecure=true  # Dashboard without auth (localhost only)
    
    # Docker provider
    - --providers.docker=true
    - --providers.docker.exposedbydefault=false
    - --providers.docker.network=traefik
    
    # Entry points
    - --entrypoints.web.address=:80
    - --entrypoints.websecure.address=:443
    
    # SSL
    - --certificatesresolvers.myresolver.acme.tlschallenge=true
    - --certificatesresolvers.myresolver.acme.email=${TRAEFIK_EMAIL}
    - --certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json
    
    # Logging
    - --log.level=INFO
    - --accesslog=true
    
    # Metrics
    - --metrics.prometheus=true
```

### Service Labels

Example from Jellyfin:

```yaml
jellyfin:
  labels:
    # Enable Traefik for this service
    - "traefik.enable=true"
    
    # Which Docker network to use
    - "traefik.docker.network=traefik"
    
    # HTTP (port 80) routing
    - "traefik.http.routers.jellyfin.entrypoints=web"
    - "traefik.http.routers.jellyfin.rule=Host(`media.${HOMELAB_DOMAIN}`)"
    - "traefik.http.services.jellyfin.loadbalancer.server.port=8096"
    
    # HTTPS (port 443) routing
    - "traefik.http.routers.jellyfin-secure.entrypoints=websecure"
    - "traefik.http.routers.jellyfin-secure.rule=Host(`media.${HOMELAB_DOMAIN}`)"
    - "traefik.http.routers.jellyfin-secure.tls.certresolver=myresolver"
```

### Label Breakdown

| Label | Purpose |
|-------|---------|
| `traefik.enable=true` | Tell Traefik to include this service |
| `traefik.docker.network` | Which network to use for routing |
| `routers.NAME.entrypoints` | HTTP (web) or HTTPS (websecure) |
| `routers.NAME.rule` | Matching rule (usually Host) |
| `services.NAME.loadbalancer.server.port` | Internal service port |
| `tls.certresolver` | Which cert resolver to use |

### Accessing Traefik Dashboard

**Localhost:**
```
http://localhost:7080
```

**Domain Mode:**
```
https://traefik.yourdomain.com
```

**Dashboard Features:**
- View all routes (HTTP/TCP)
- Check service health
- Monitor middleware
- View SSL certificates
- Access metrics

---

## 🔐 SSL Certificates

### Automatic SSL with Let's Encrypt

Traefik automatically obtains SSL certificates using the ACME protocol.

### Requirements

✅ Domain name pointing to your server  
✅ Ports 80 and 443 accessible from internet  
✅ Valid email address  
✅ Server can reach Let's Encrypt servers  

### Configuration

In `.env`:
```env
TRAEFIK_EMAIL=you@email.com
HOMELAB_DOMAIN=lab.yourdomain.com
```

### How It Works

```
1. User requests https://media.lab.yourdomain.com
2. Traefik checks if certificate exists
3. If not, initiates ACME challenge:
   - Let's Encrypt sends challenge to port 80
   - Traefik responds with verification
   - Let's Encrypt issues certificate
4. Certificate stored in /letsencrypt/acme.json
5. Certificate auto-renewed before expiry
```

### Certificate Storage

```bash
# Location
config/traefik/letsencrypt/acme.json

# Check certificates
docker compose exec traefik cat /letsencrypt/acme.json | jq '.myresolver.Certificates[] | .domain.main'
```

### Certificate Renewal

- **Automatic**: Traefik renews 30 days before expiry
- **Manual**: Restart Traefik to force check
  ```bash
  docker compose restart traefik
  ```

### Certificate Troubleshooting

**Check Traefik logs:**
```bash
docker compose logs traefik | grep -i acme
docker compose logs traefik | grep -i certificate
```

**Common Issues:**

1. **Port 80 not accessible**
   - Solution: Check port forwarding
   - Test: `curl http://yourdomain.com`

2. **Rate limit exceeded**
   - Let's Encrypt limits: 5 failures per hour
   - Solution: Wait and ensure config is correct
   - Use staging environment for testing

3. **DNS not resolving**
   - Solution: Wait for DNS propagation (up to 48 hours)
   - Test: `nslookup yourdomain.com`

### Testing SSL (Staging)

Use Let's Encrypt staging for testing:

```yaml
# In docker-compose.yml (temporarily)
- --certificatesresolvers.myresolver.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory
```

> ⚠️ Remove staging server URL for production!

---

## 🌍 DNS Configuration

### DNS Records Setup

#### 1. Get Your Public IP

```bash
curl ifconfig.me
# or
curl https://api.ipify.org
```

#### 2. Configure DNS Records

Log into your domain registrar and add:

**A Records:**
```
lab.yourdomain.com          → Your.Public.IP.Address
*.lab.yourdomain.com        → Your.Public.IP.Address
```

**Or individual subdomains:**
```
dashboard.lab.yourdomain.com → Your.Public.IP.Address
media.lab.yourdomain.com     → Your.Public.IP.Address
music.lab.yourdomain.com     → Your.Public.IP.Address
home.lab.yourdomain.com      → Your.Public.IP.Address
...
```

#### 3. Verify DNS Propagation

```bash
# Check A record
nslookup dashboard.lab.yourdomain.com

# Check propagation globally
# Visit: https://www.whatsmydns.net/
```

### Dynamic DNS (DDNS)

If your public IP changes frequently:

**Options:**
1. **Router DDNS**: Most routers support services like DynDNS, No-IP
2. **Cloudflare**: Free DDNS with API
3. **Docker Container**: `oznu/cloudflare-ddns`

**Cloudflare DDNS Example:**
```yaml
cloudflare-ddns:
  image: oznu/cloudflare-ddns:latest
  environment:
    API_KEY: your_cloudflare_api_key
    ZONE: yourdomain.com
    SUBDOMAIN: lab
```

### Local DNS (Hosts File)

For local testing without internet:

**Linux/macOS:** `/etc/hosts`
**Windows:** `C:\Windows\System32\drivers\etc\hosts`

```
192.168.1.100 dashboard.lab.yourdomain.com
192.168.1.100 media.lab.yourdomain.com
192.168.1.100 music.lab.yourdomain.com
```

---

## 🔒 VPN Access (WireGuard)

### Why VPN?

- ✅ Secure remote access to homelab
- ✅ No need to expose all services to internet
- ✅ Encrypted traffic
- ✅ Access from anywhere

### WireGuard Setup

#### 1. Configure in `.env`

```env
# Your server's public IP or domain
HOMELAB_SERVER_IP=your.public.ip

# VPN port (UDP)
WG_PORT=51820

# WireGuard UI port
WG_UI_PORT=7518

# Generate password hash
WG_UI_PASSWORD_HASH=your_bcrypt_hash

# VPN client address range
WG_DEFAULT_ADDRESS=10.8.0.x

# DNS for VPN clients
WG_DEFAULT_DNS=1.1.1.1

# Routes (0.0.0.0/0 = all traffic through VPN)
WG_ALLOWED_IPS=192.168.1.0/24
```

#### 2. Generate Password Hash

**Online:** https://bcrypt-generator.com/  
**Command Line:**
```bash
htpasswd -nbB admin yourpassword | cut -d ":" -f 2
```

#### 3. Port Forward Router

Forward UDP port `51820` to your server's IP

#### 4. Deploy WireGuard

```bash
docker compose --profile networking up -d wireguard
```

#### 5. Access WireGuard UI

```
http://your-server-ip:7518
```

### Creating VPN Clients

1. Access WireGuard UI
2. Click "New Client"
3. Enter client name (e.g., "iPhone", "Laptop")
4. Click "Create"
5. Scan QR code or download config file

### Client Setup

**Mobile (iOS/Android):**
1. Install WireGuard app
2. Scan QR code from UI
3. Enable VPN

**Desktop (Windows/macOS/Linux):**
1. Install WireGuard client
2. Import config file
3. Activate tunnel

### Testing VPN Connection

```bash
# Before connecting
curl https://ipinfo.io/ip

# After connecting
curl https://ipinfo.io/ip  # Should show VPN server IP

# Access local services
curl http://192.168.1.100:7081
```

### VPN Routing Strategies

**Split Tunnel** (Access homelab only):
```env
WG_ALLOWED_IPS=192.168.1.0/24
```
- Internet traffic: Direct
- Homelab traffic: Through VPN

**Full Tunnel** (All traffic through VPN):
```env
WG_ALLOWED_IPS=0.0.0.0/0
```
- All traffic: Through VPN
- More secure, but slower

---

## 🛡️ Pi-hole Setup

### What is Pi-hole?

Network-wide ad blocker and DNS server:
- Blocks ads at DNS level
- Works on all devices
- Local DNS records
- Query logging and statistics

### Configuration

#### 1. Deploy Pi-hole

```bash
docker compose --profile networking up -d pihole
```

#### 2. Access Web Interface

```
http://your-server-ip:8084/admin
```

**Login:**
- Password: See `.env` file (`PIHOLE_PASSWORD`)

#### 3. Configure Router

**Option A: Router DNS Settings**
1. Log into router admin
2. Find DHCP settings
3. Set Primary DNS to your server IP: `192.168.1.100`
4. Set Secondary DNS to: `1.1.1.1` (backup)
5. Save and restart router

**Option B: Per-Device Configuration**
Configure DNS manually on each device:
- **Windows**: Network Adapter Settings
- **macOS**: System Preferences → Network
- **Linux**: `/etc/resolv.conf`

#### 4. Verify Pi-hole is Working

```bash
# Test DNS resolution
nslookup google.com 192.168.1.100

# Check if ads are blocked
nslookup doubleclick.net 192.168.1.100
# Should return 0.0.0.0 or block page
```

### Adding Blocklists

**Popular Lists:**
- StevenBlack's Unified Hosts: Comprehensive
- EasyList: General ads
- Malware Domain List: Security

**Add in Pi-hole:**
1. Go to Group Management → Adlists
2. Add list URL
3. Tools → Update Gravity

### Local DNS Records

Add custom DNS entries for your services:

**Pi-hole UI:**
1. Local DNS → DNS Records
2. Add entries:
   ```
   dashboard.lab → 192.168.1.100
   media.lab     → 192.168.1.100
   music.lab     → 192.168.1.100
   ```

**Or via CLI:**
```bash
docker compose exec pihole pihole -a hostrecord dashboard.lab 192.168.1.100
```

---

## 🔐 Security Hardening

### Security Checklist

#### Level 1: Essential (Do This First)

- [ ] Change ALL default passwords in `.env`
- [ ] Use strong passwords (20+ characters, random)
- [ ] Don't expose unnecessary ports
- [ ] Enable firewall
- [ ] Keep system updated

#### Level 2: Recommended

- [ ] Set up WireGuard VPN for remote access
- [ ] Enable Pi-hole for network protection
- [ ] Configure fail2ban (SSH protection)
- [ ] Use Traefik security headers
- [ ] Regular backups
- [ ] Enable 2FA on critical services

#### Level 3: Advanced

- [ ] Implement SSO (Single Sign-On)
- [ ] Use Docker secrets instead of .env
- [ ] Network segmentation (VLANs)
- [ ] Intrusion detection (Snort/Suricata)
- [ ] Log aggregation and monitoring
- [ ] Regular security audits

### Traefik Security Headers

Add to service labels:

```yaml
labels:
  # Security headers
  - "traefik.http.middlewares.security-headers.headers.framedeny=true"
  - "traefik.http.middlewares.security-headers.headers.sslredirect=true"
  - "traefik.http.middlewares.security-headers.headers.stsSeconds=31536000"
  - "traefik.http.middlewares.security-headers.headers.stsIncludeSubdomains=true"
  - "traefik.http.middlewares.security-headers.headers.contentTypeNosniff=true"
  - "traefik.http.middlewares.security-headers.headers.browserXssFilter=true"
  
  # Apply to router
  - "traefik.http.routers.jellyfin-secure.middlewares=security-headers"
```

### Basic Auth Protection

For services without built-in auth:

```bash
# Generate password hash
htpasswd -nb admin yourpassword
# Output: admin:$apr1$xyz...
```

```yaml
labels:
  # Create auth middleware
  - "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$xyz..."
  
  # Apply to router
  - "traefik.http.routers.service-secure.middlewares=auth"
```

### Rate Limiting

Prevent brute force attacks:

```yaml
labels:
  # Rate limit: 100 requests per minute
  - "traefik.http.middlewares.rate-limit.ratelimit.average=100"
  - "traefik.http.middlewares.rate-limit.ratelimit.burst=50"
  
  # Apply to router
  - "traefik.http.routers.service-secure.middlewares=rate-limit"
```

---

## 🧱 Firewall Configuration

### UFW (Ubuntu)

```bash
# Install
sudo apt install ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (don't lock yourself out!)
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS (for Traefik)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow WireGuard
sudo ufw allow 51820/udp

# Allow DNS (if using Pi-hole)
sudo ufw allow 53/tcp
sudo ufw allow 53/udp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

### firewalld (CentOS/RHEL/Fedora)

```bash
# Install
sudo dnf install firewalld

# Start service
sudo systemctl start firewalld
sudo systemctl enable firewalld

# Add services
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=51820/udp

# Reload
sudo firewall-cmd --reload

# Check status
sudo firewall-cmd --list-all
```

### Windows Firewall

```powershell
# Allow HTTP
New-NetFirewallRule -DisplayName "HTTP" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow

# Allow HTTPS
New-NetFirewallRule -DisplayName "HTTPS" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow

# Allow WireGuard
New-NetFirewallRule -DisplayName "WireGuard" -Direction Inbound -LocalPort 51820 -Protocol UDP -Action Allow
```

---

## 🔍 Troubleshooting

### Common Issues

#### Cannot Access Services Externally

**Check:**
1. DNS records configured correctly
2. Port forwarding enabled on router
3. Firewall allows ports 80/443
4. Traefik is running: `docker compose ps traefik`
5. Services have correct labels

**Test:**
```bash
# Test from outside your network
curl -I http://yourdomain.com

# Should see Traefik response
```

#### SSL Certificate Not Working

**Check:**
```bash
# View Traefik logs
docker compose logs traefik | grep -i acme

# Common issues:
# - Port 80 blocked
# - DNS not resolving
# - Rate limit exceeded
```

#### VPN Not Connecting

**Check:**
1. Port forwarding: UDP 51820
2. Firewall allows UDP 51820
3. WireGuard container running
4. Correct public IP in config

**Test:**
```bash
# From server
sudo nmap -sU -p 51820 your.public.ip
```

#### Pi-hole Not Blocking Ads

**Check:**
1. DNS configured correctly on devices
2. Gravity database updated
3. Blocklists enabled

**Test:**
```bash
# Test DNS query
nslookup doubleclick.net $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' pihole)
```

### Network Diagnostic Commands

```bash
# Check open ports
netstat -tuln

# Test DNS resolution
dig @192.168.1.100 google.com

# Trace network path
traceroute google.com

# Check Docker networks
docker network ls
docker network inspect traefik

# View all routing rules
docker compose exec traefik cat /etc/traefik/traefik.yml
```

---

## 📚 Additional Resources

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [WireGuard Documentation](https://www.wireguard.com/quickstart/)
- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Docker Networking](https://docs.docker.com/network/)

---

[⬅ Back to Main README](../README.md)