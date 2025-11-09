#!/usr/bin/env bash

# ==============================================================================
# HOMELAB UNIVERSAL SETUP SCRIPT v3.1
# Works on: Linux, macOS, Windows (Git Bash/WSL/MSYS2/Cygwin)
# ==============================================================================

# Disable strict error checking for directory creation
set +eo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

readonly SCRIPT_VERSION="3.1.0"
readonly SCRIPT_NAME="Homelab Universal Setup"

# Colors - with fallback for non-color terminals
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    PURPLE=''
    CYAN=''
    WHITE=''
    NC=''
fi

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

print_header() {
    echo ""
    echo "================================================================"
    echo "  $1"
    echo "================================================================"
    echo ""
}

print_section() {
    echo ""
    echo "----------------------------------------------------------------"
    echo "  $1"
    echo "----------------------------------------------------------------"
}

print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1" >&2; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }
print_step() { echo -e "${CYAN}[→]${NC} $1"; }

# ==============================================================================
# CROSS-PLATFORM COMPATIBILITY
# ==============================================================================

detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "Linux";;
        Darwin*)    echo "macOS";;
        CYGWIN*)    echo "Windows";;
        MINGW*)     echo "Windows";;
        MSYS*)      echo "Windows";;
        *)          echo "Unknown";;
    esac
}

normalize_path() {
    local path="$1"
    
    # Handle Windows paths in Git Bash/MSYS
    if [[ "$OS_TYPE" == "Windows" ]]; then
        # Convert C:\path to /c/path
        if [[ "$path" =~ ^[A-Za-z]: ]]; then
            local drive="${path:0:1}"
            drive=$(echo "$drive" | tr '[:upper:]' '[:lower:]')
            path="/${drive}${path:2}"
        fi
        # Replace backslashes with forward slashes
        path="${path//\\//}"
    fi
    
    echo "$path"
}

safe_mkdir() {
    local dir="$1"
    local normalized
    normalized=$(normalize_path "$dir")
    
    # Check if already exists
    if [[ -d "$normalized" ]]; then
        return 0
    fi
    
    # Try standard mkdir
    if mkdir -p "$normalized" 2>/dev/null; then
        return 0
    fi
    
    # On Windows, try alternative methods
    if [[ "$OS_TYPE" == "Windows" ]]; then
        # Try with Windows native paths
        local winpath
        winpath=$(echo "$normalized" | sed 's|^/\([a-z]\)/|\1:/|')
        
        # Try cmd mkdir
        if cmd //c "mkdir \"$winpath\"" 2>/dev/null; then
            return 0
        fi
        
        # Try PowerShell
        if powershell.exe -Command "New-Item -ItemType Directory -Force -Path '$winpath'" 2>/dev/null; then
            return 0
        fi
    fi
    
    # If all fails, just continue (don't fail the whole script)
    print_warning "Could not create directory: $dir (Docker volumes will handle it)"
    return 0
}

check_command() {
    command -v "$1" &> /dev/null
}

# ==============================================================================
# ERROR HANDLING
# ==============================================================================

cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        print_error "Setup failed with exit code: $exit_code"
        print_info "You can run 'docker compose down' to clean up"
    fi
    exit "$exit_code"
}

trap cleanup_on_error EXIT

# ==============================================================================
# PREREQUISITES
# ==============================================================================

check_prerequisites() {
    print_section "CHECKING PREREQUISITES"
    
    local all_good=true
    
    # Detect OS
    OS_TYPE=$(detect_os)
    print_info "Detected OS: $OS_TYPE"
    
    # Check Docker
    if check_command docker; then
        if docker version &> /dev/null; then
            local docker_version
            docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
            print_success "Docker is running (v${docker_version})"
        else
            print_error "Docker is installed but not running"
            print_info "Please start Docker Desktop and try again"
            all_good=false
        fi
    else
        print_error "Docker is not installed"
        print_info "Install from: https://www.docker.com/products/docker-desktop"
        all_good=false
    fi
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        local compose_version
        compose_version=$(docker compose version --short 2>/dev/null || echo "unknown")
        print_success "Docker Compose available (v${compose_version})"
    else
        print_error "Docker Compose is not available"
        all_good=false
    fi
    
    # Check .env file
    if [[ -f ".env" ]]; then
        print_success "Configuration file (.env) found"
    else
        print_error ".env file not found"
        print_info "Please create .env file first"
        all_good=false
    fi
    
    # Check docker-compose.yml
    if [[ -f "docker-compose.yml" ]]; then
        print_success "Docker Compose file found"
        
        # Validate syntax
        if docker compose config &> /dev/null; then
            print_success "Docker Compose file is valid"
        else
            print_warning "Docker Compose file may have syntax issues"
        fi
    else
        print_error "docker-compose.yml not found"
        all_good=false
    fi
    
    # Check Docker resources
    local docker_mem
    docker_mem=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)
    if [[ $docker_mem -gt 0 ]]; then
        docker_mem=$((docker_mem / 1024 / 1024 / 1024))
        if [[ $docker_mem -ge 4 ]]; then
            print_success "Docker memory: ${docker_mem}GB"
        else
            print_warning "Docker memory: ${docker_mem}GB (4GB+ recommended)"
        fi
    fi
    
    if [[ "$all_good" == false ]]; then
        print_error "Prerequisites check failed"
        exit 1
    fi
    
    print_success "All prerequisites met!"
}

# ==============================================================================
# ENVIRONMENT
# ==============================================================================

load_environment() {
    print_section "LOADING ENVIRONMENT"
    
    if [[ ! -f ".env" ]]; then
        print_error "Cannot find .env file"
        exit 1
    fi
    
    # Load .env safely
    set -a
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        
        # Remove quotes from value
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        
        # Export variable
        export "$key=$value"
    done < .env
    set +a
    
    # Set defaults
    HOMELAB_DOMAIN="${HOMELAB_DOMAIN:-lab}"
    CONFIG_PATH="${CONFIG_PATH:-./config}"
    MEDIA_PATH="${MEDIA_PATH:-./media}"
    BACKUP_PATH="${BACKUP_PATH:-./backups}"
    
    # Normalize paths for Windows
    CONFIG_PATH=$(normalize_path "$CONFIG_PATH")
    MEDIA_PATH=$(normalize_path "$MEDIA_PATH")
    BACKUP_PATH=$(normalize_path "$BACKUP_PATH")
    
    print_success "Environment loaded"
    print_info "Domain: ${HOMELAB_DOMAIN}"
    print_info "Config: ${CONFIG_PATH}"
    print_info "Media: ${MEDIA_PATH}"
}

# ==============================================================================
# SERVICE SELECTION
# ==============================================================================

show_service_menu() {
    print_section "SERVICE SELECTION"
    echo ""
    echo "  1.  Complete Stack (all services)"
    echo "  2.  Core Services (traefik, heimdall, searxng)"
    echo "  3.  Monitoring (uptime-kuma, grafana, influxdb)"
    echo "  4.  IoT & Automation (home-assistant, nodered, mosquitto)"
    echo "  5.  Robotics & Development (ros, jupyter, code-server)"
    echo "  6.  Productivity (karakeep, outline, filebrowser)"
    echo "  7.  Automation Workflow (n8n)"
    echo "  8.  Database Services (postgres, redis, timescaledb)"
    echo "  9.  File Services (syncthing, filebrowser)"
    echo "  10. Networking (pihole, wireguard)"
    echo "  11. Media Stack (jellyfin, sonarr, radarr)"
    echo "  12. Music Services (lidarr, navidrome)"
    echo ""
}

get_selection() {
    local choice
    read -p "Choose option (1-12) [2 for core]: " choice
    choice=${choice:-2}
    
    case $choice in
        1) echo "all" ;;
        2) echo "core" ;;
        3) echo "monitoring" ;;
        4) echo "iot" ;;
        5) echo "robotics" ;;
        6) echo "productivity" ;;
        7) echo "workflow" ;;
        8) echo "databases" ;;
        9) echo "files" ;;
        10) echo "networking" ;;
        11) echo "media" ;;
        12) echo "music" ;;
        *) echo "core" ;;
    esac
}

# ==============================================================================
# DIRECTORY CREATION
# ==============================================================================

create_directories() {
    print_section "CREATING DIRECTORIES"
    
    local created=0
    local failed=0
    
    # Base directories - create these first with detailed error handling
    print_step "Creating base directories..."
    
    for base in "$CONFIG_PATH" "$MEDIA_PATH" "$BACKUP_PATH"; do
        print_info "Creating: $base"
        
        # Try to create
        if safe_mkdir "$base"; then
            if [[ -d "$base" ]]; then
                print_success "OK: $base"
                ((created++))
            else
                print_warning "Not verified: $base (but continuing)"
            fi
        else
            print_warning "Skipped: $base"
            ((failed++))
        fi
    done
    
    # Service directories - continue even if some fail
    print_step "Creating service directories..."
    local services=(
        "traefik/letsencrypt" "traefik/dynamic" "heimdall" "searxng"
        "uptime-kuma" "grafana" "influxdb2" "telegraf"
        "homeassistant" "mosquitto/config" "mosquitto/data" "mosquitto/log"
        "nodered/data" "esphome" "zigbee2mqtt"
        "postgres/data" "redis/data" "timescaledb/data"
        "n8n/data" "karakeep/data" "karakeep/meilisearch"
        "jellyfin/config" "sonarr" "radarr" "prowlarr" "ombi" "qbittorrent"
        "lidarr" "navidrome/data" "pihole/etc-pihole" "pihole/etc-dnsmasq.d"
        "wireguard" "syncthing" "filebrowser" "outline/data" "outline/uploads"
        "jupyter" "code-server" "mlflow" "opencv" "ros"
    )
    
    for svc in "${services[@]}"; do
        safe_mkdir "${CONFIG_PATH}/${svc}" || true
    done
    
    # Media directories
    print_step "Creating media directories..."
    for media in "movies" "tv" "music" "photos" "homevideos" "documents" "downloads"; do
        safe_mkdir "${MEDIA_PATH}/${media}" || true
    done
    
    # Backup directory
    safe_mkdir "${BACKUP_PATH}/postgres" || true
    
    print_success "Directory setup completed"
    print_info "Note: Some directories may have been skipped but Docker volumes will handle them"
}

# ==============================================================================
# CONFIGURATION FILES
# ==============================================================================

create_configs() {
    print_section "CREATING CONFIGURATION FILES"
    
    # Ensure config directory exists
    safe_mkdir "${CONFIG_PATH}/mosquitto/config"
    safe_mkdir "${CONFIG_PATH}/telegraf"
    
    # Mosquitto config
    local mosquitto_conf="${CONFIG_PATH}/mosquitto/config/mosquitto.conf"
    if [[ ! -f "$mosquitto_conf" ]]; then
        print_step "Creating Mosquitto config..."
        cat > "$mosquitto_conf" << 'EOF'
listener 1883 0.0.0.0
protocol mqtt
listener 9001 0.0.0.0
protocol websockets
allow_anonymous true
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
log_dest stdout
max_connections -1
autosave_interval 1800
EOF
        print_success "Mosquitto config created"
    else
        print_info "Mosquitto config exists"
    fi
    
    # Telegraf config
    local telegraf_conf="${CONFIG_PATH}/telegraf/telegraf.conf"
    if [[ ! -f "$telegraf_conf" ]]; then
        print_step "Creating Telegraf config..."
        cat > "$telegraf_conf" << 'EOF'
[agent]
  interval = "60s"
  round_interval = true

[[outputs.influxdb_v2]]
  urls = ["http://influxdb:8086"]
  token = "${INFLUXDB_TOKEN}"
  organization = "${INFLUXDB_ORG}"
  bucket = "${INFLUXDB_BUCKET}"

[[inputs.cpu]]
  percpu = true
  totalcpu = true

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs"]

[[inputs.mem]]

[[inputs.docker]]
  endpoint = "unix:///var/run/docker.sock"
  timeout = "5s"
EOF
        print_success "Telegraf config created"
    else
        print_info "Telegraf config exists"
    fi
    
    # Database init script
    print_step "Creating database init script..."
    safe_mkdir "./scripts"
    cat > "./scripts/init-databases.sh" << 'EOF'
#!/bin/bash
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE n8n;
    CREATE DATABASE outline;
    CREATE DATABASE outline_test;
    GRANT ALL PRIVILEGES ON DATABASE n8n TO $POSTGRES_USER;
    GRANT ALL PRIVILEGES ON DATABASE outline TO $POSTGRES_USER;
    GRANT ALL PRIVILEGES ON DATABASE outline_test TO $POSTGRES_USER;
EOSQL
EOF
    chmod +x "./scripts/init-databases.sh" 2>/dev/null || true
    print_success "Database init script created"
}

# ==============================================================================
# DOCKER NETWORK
# ==============================================================================

setup_networks() {
    print_section "SETTING UP DOCKER NETWORKS"
    
    if docker network inspect traefik &> /dev/null; then
        print_info "Traefik network exists"
    else
        print_step "Creating traefik network..."
        if docker network create traefik 2>/dev/null; then
            print_success "Traefik network created"
        else
            print_warning "Could not create network"
        fi
    fi
}

# ==============================================================================
# SERVICE DEPLOYMENT
# ==============================================================================

deploy_services() {
    local profile=$1
    
    print_section "DEPLOYING SERVICES: ${profile}"
    
    print_warning "This may take several minutes..."
    sleep 2
    
    case $profile in
        all)
            print_step "Starting ALL services..."
            docker compose --profile all up -d --remove-orphans
            ;;
        core)
            print_step "Starting core services..."
            docker compose --profile core up -d --remove-orphans
            ;;
        monitoring)
            print_step "Starting monitoring services..."
            docker compose --profile monitoring up -d --remove-orphans
            ;;
        iot)
            print_step "Starting IoT services..."
            docker compose --profile iot up -d --remove-orphans
            ;;
        robotics)
            print_step "Starting robotics services..."
            docker compose --profile robotics up -d --remove-orphans
            ;;
        productivity)
            print_step "Starting productivity services..."
            docker compose --profile productivity up -d --remove-orphans
            ;;
        workflow)
            print_step "Starting workflow services..."
            docker compose --profile workflow up -d --remove-orphans
            ;;
        databases)
            print_step "Starting database services..."
            docker compose --profile databases up -d --remove-orphans
            ;;
        files)
            print_step "Starting file services..."
            docker compose --profile files up -d --remove-orphans
            ;;
        networking)
            print_step "Starting networking services..."
            docker compose --profile networking up -d --remove-orphans
            ;;
        media)
            print_step "Starting media services..."
            docker compose --profile media up -d --remove-orphans
            ;;
        music)
            print_step "Starting music services..."
            docker compose --profile music up -d --remove-orphans
            ;;
        *)
            print_error "Unknown profile: $profile"
            return 1
            ;;
    esac
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "Services deployed successfully!"
    else
        print_error "Deployment failed (exit code: $exit_code)"
        return $exit_code
    fi
}

# ==============================================================================
# VERIFICATION
# ==============================================================================

verify_deployment() {
    print_section "VERIFYING DEPLOYMENT"
    
    print_info "Waiting for services to initialize (10 seconds)..."
    sleep 10
    
    print_step "Checking service status..."
    echo ""
    
    if docker compose ps 2>/dev/null; then
        echo ""
        local running
        running=$(docker compose ps --services 2>/dev/null | wc -l || echo "0")
        print_success "$running service(s) configured"
    else
        print_warning "Could not retrieve service status"
    fi
}

# ==============================================================================
# ACCESS INFORMATION
# ==============================================================================

show_access_info() {
    local profile=$1
    
    print_section "SERVICE ACCESS"
    
    echo ""
    echo "HOW TO ACCESS YOUR SERVICES:"
    echo ""
    echo "1. Via Localhost:"
    echo "   http://localhost:${HEIMDALL_PORT:-7081} (Dashboard)"
    echo "   http://localhost:8123 (Home Assistant)"
    echo ""
    echo "2. Via Domain (add to hosts file):"
    echo "   http://dashboard.${HOMELAB_DOMAIN}"
    echo "   http://home.${HOMELAB_DOMAIN}"
    echo ""
    echo "3. From Network:"
    echo "   http://${HOMELAB_SERVER_IP:-192.168.100.151}:${HEIMDALL_PORT:-7081}"
    echo ""
    
    case $profile in
        all|core)
            echo "CORE SERVICES:"
            echo "  Dashboard:  http://localhost:${HEIMDALL_PORT:-7081}"
            echo "  Search:     http://localhost:${SEARXNG_PORT:-7082}"
            echo "  Traefik:    http://localhost:${TRAEFIK_DASHBOARD_PORT:-7080}"
            echo ""
            ;;
    esac
    
    case $profile in
        all|monitoring)
            echo "MONITORING:"
            echo "  Uptime:     http://localhost:${UPTIME_KUMA_PORT:-7001}"
            echo "  Grafana:    http://localhost:${GRAFANA_PORT:-7300}"
            echo "  InfluxDB:   http://localhost:8086"
            echo ""
            ;;
    esac
    
    case $profile in
        all|iot)
            echo "IOT & AUTOMATION:"
            echo "  Home Asst:  http://localhost:8123"
            echo "  Node-RED:   http://localhost:${NODERED_PORT:-7180}"
            echo "  ESPHome:    http://localhost:${ESPHOME_PORT:-7605}"
            echo ""
            ;;
    esac
    
    case $profile in
        all|media)
            echo "MEDIA:"
            echo "  Jellyfin:   http://localhost:${JELLYFIN_PORT:-7096}"
            echo "  Sonarr:     http://localhost:8989"
            echo "  Radarr:     http://localhost:7878"
            echo ""
            ;;
    esac
}

# ==============================================================================
# UTILITY SCRIPTS
# ==============================================================================

create_utility_scripts() {
    print_section "CREATING UTILITY SCRIPTS"
    
    safe_mkdir "./scripts"
    
    # Backup script
    print_step "Creating backup script..."
    cat > "./scripts/backup.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

BACKUP_DIR="${BACKUP_PATH:-./backups}/$(date +%Y%m%d_%H%M%S)"
CONFIG_DIR="${CONFIG_PATH:-./config}"

echo "Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

echo "Backing up configurations..."
tar -czf "$BACKUP_DIR/config_backup.tar.gz" "$CONFIG_DIR" 2>/dev/null || true

echo "Backing up databases..."
docker compose exec -T postgres pg_dumpall -U "${POSTGRES_USER:-homelab_user}" \
  > "$BACKUP_DIR/postgres_dump.sql" 2>/dev/null || true

echo "Backing up environment..."
cp .env "$BACKUP_DIR/.env.backup" 2>/dev/null || true
cp docker-compose.yml "$BACKUP_DIR/docker-compose.yml.backup" 2>/dev/null || true

echo "Backup completed: $BACKUP_DIR"
EOF
    chmod +x "./scripts/backup.sh" 2>/dev/null || true
    print_success "Backup script created"
    
    # Health check script
    print_step "Creating health check script..."
    cat > "./scripts/health-check.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

echo "================================"
echo "HOMELAB HEALTH CHECK"
echo "================================"
echo ""

echo "Docker Status:"
if docker ps &> /dev/null; then
    echo "  [✓] Docker is running"
    echo "  Containers: $(docker ps -q | wc -l) running"
else
    echo "  [✗] Docker is not responding"
    exit 1
fi
echo ""

echo "Service Status:"
docker compose ps
echo ""

echo "Disk Usage:"
df -h . 2>/dev/null | tail -1 || echo "  Unable to check disk usage"
echo ""

echo "Docker Resources:"
docker system df
echo ""

UNHEALTHY=$(docker ps --filter health=unhealthy --format "{{.Names}}" 2>/dev/null | wc -l)
if [ "$UNHEALTHY" -gt 0 ]; then
    echo "[!] Warning: $UNHEALTHY unhealthy container(s)"
else
    echo "[✓] All containers healthy"
fi
echo ""

echo "Health check completed"
EOF
    chmod +x "./scripts/health-check.sh" 2>/dev/null || true
    print_success "Health check script created"
}

# ==============================================================================
# NEXT STEPS
# ==============================================================================

show_next_steps() {
    print_section "NEXT STEPS"
    
    echo ""
    echo "1. Access your dashboard:"
    echo "   http://localhost:${HEIMDALL_PORT:-7081}"
    echo ""
    echo "2. Change default passwords in .env"
    echo ""
    echo "3. Useful commands:"
    echo "   docker compose ps              # List services"
    echo "   docker compose logs -f <svc>   # View logs"
    echo "   docker compose restart <svc>   # Restart service"
    echo "   docker compose stop            # Stop all"
    echo "   docker compose down            # Stop and remove"
    echo ""
    echo "4. Run health check:"
    echo "   ./scripts/health-check.sh"
    echo ""
    echo "5. Create backup:"
    echo "   ./scripts/backup.sh"
    echo ""
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    clear
    print_header "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "Cross-platform Docker Compose deployment"
    echo ""
    
    # Run setup
    check_prerequisites
    load_environment
    
    # Show menu
    show_service_menu
    PROFILE=$(get_selection)
    
    print_info "Selected: $PROFILE"
    echo ""
    
    read -p "Proceed with deployment? [Y/n]: " confirm
    confirm=${confirm:-Y}
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Cancelled by user"
        exit 0
    fi
    
    # Setup infrastructure
    create_directories
    create_configs
    setup_networks
    create_utility_scripts
    
    # Deploy
    deploy_services "$PROFILE"
    
    # Verify and show info
    verify_deployment
    show_access_info "$PROFILE"
    show_next_steps
    
    # Done
    print_header "DEPLOYMENT COMPLETE!"
    echo ""
    print_success "Your homelab is ready!"
    print_warning "Remember to change default passwords!"
    echo ""
}

# Run main
main "$@"