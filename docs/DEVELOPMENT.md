# 🛠️ Development & Contributing Guide

Guide for contributing to the homelab project, adding new services, and customizing your setup.

---

## 📑 Table of Contents

- [Getting Started](#-getting-started)
- [Project Structure](#-project-structure)
- [Adding New Services](#-adding-new-services)
- [Creating Profiles](#-creating-profiles)
- [Documentation Guidelines](#-documentation-guidelines)
- [Testing](#-testing)
- [Contributing](#-contributing)
- [Code Style](#-code-style)

---

## 🚀 Getting Started

### Development Environment

**Required:**
- Docker Desktop or Docker Engine
- Docker Compose v2+
- Git
- Text editor (VS Code recommended)

**Recommended:**
- `docker-compose` v2.20+
- `yamllint` for YAML validation
- `shellcheck` for shell script validation
- VS Code extensions:
  - Docker
  - YAML
  - ShellCheck

### Fork and Clone

```bash
# 1. Fork the repository on GitHub
# https://github.com/r-o-k-u/Homelab

# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/Homelab.git
cd Homelab

# 3. Add upstream remote
git remote add upstream https://github.com/r-o-k-u/Homelab.git

# 4. Create development branch
git checkout -b feature/your-feature-name
```

### Development Workflow

```bash
# 1. Pull latest changes
git checkout main
git pull upstream main

# 2. Create feature branch
git checkout -b feature/add-service-name

# 3. Make changes
# Edit docker-compose.yml, add docs, etc.

# 4. Test changes
docker compose config  # Validate syntax
./scripts/health-check.sh  # Test functionality

# 5. Commit changes
git add .
git commit -m "feat: add ServiceName with profile"

# 6. Push to your fork
git push origin feature/add-service-name

# 7. Create Pull Request
# Go to GitHub and create PR
```

---

## 📁 Project Structure

### Directory Layout

```
Homelab/
├── docker-compose.yml          # Main service definitions
├── .env.example                # Environment template
├── .env                        # Your config (not in git)
├── README.md                   # Main documentation
├── LICENSE                     # MIT License
│
├── docs/                       # Documentation
│   ├── QUICKSTART.md          # Getting started
│   ├── ARCHITECTURE.md        # System design
│   ├── SERVICES.md            # Service catalog
│   ├── NETWORKING.md          # Network guide
│   ├── OPERATIONS.md          # Operations guide
│   ├── TROUBLESHOOTING.md     # Problem solving
│   └── DEVELOPMENT.md         # This file
│
├── scripts/                    # Utility scripts
│   ├── setup.sh               # Universal setup
│   ├── backup.sh              # Backup automation
│   ├── health-check.sh        # Health monitoring
│   ├── init-databases.sh      # DB initialization
│   └── pg_hba.conf            # PostgreSQL config
│
├── config/                     # Service configs (auto-created)
│   ├── traefik/
│   ├── jellyfin/
│   └── [service]/
│
├── media/                      # Media storage (auto-created)
│   ├── movies/
│   ├── tv/
│   └── music/
│
└── backups/                    # Backup storage (auto-created)
```

### Key Files

| File | Purpose | When to Edit |
|------|---------|--------------|
| `docker-compose.yml` | Service definitions | Adding/modifying services |
| `.env.example` | Config template | Adding new variables |
| `docs/SERVICES.md` | Service documentation | Documenting new services |
| `scripts/setup.sh` | Setup automation | Changing setup process |
| `README.md` | Main documentation | Major changes |

---

## ➕ Adding New Services

### Step-by-Step Guide

#### 1. Choose Service Details

Decide on:
- Service name (lowercase, hyphens for spaces)
- Docker image and version
- Ports needed
- Volumes required
- Dependencies
- Profile(s) it belongs to

#### 2. Add to docker-compose.yml

```yaml
services:
  your-service:
    image: username/service:tag
    container_name: your-service
    <<: *restart-policy          # Use common restart policy
    environment:
      <<: *common-variables       # TZ, PUID, PGID
      SERVICE_SPECIFIC_VAR: ${SERVICE_VAR:-default}
    volumes:
      - ${CONFIG_PATH}/your-service:/config
      - ${DATA_PATH}:/data
    ports:
      - "${SERVICE_PORT:-7777}:8080"
    networks:
      - traefik                   # If web accessible
      - internal                  # If needs backend services
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      <<: *healthcheck-defaults
    labels:
      # Enable Traefik (if web accessible)
      - "traefik.enable=true"
      - "traefik.docker.network=traefik"
      
      # HTTP routing
      - "traefik.http.routers.your-service.entrypoints=web"
      - "traefik.http.routers.your-service.rule=Host(`service.${HOMELAB_DOMAIN}`)"
      - "traefik.http.services.your-service.loadbalancer.server.port=8080"
      
      # HTTPS routing
      - "traefik.http.routers.your-service-secure.entrypoints=websecure"
      - "traefik.http.routers.your-service-secure.rule=Host(`service.${HOMELAB_DOMAIN}`)"
      - "traefik.http.routers.your-service-secure.tls.certresolver=myresolver"
    profiles: ["your-profile", "all"]
```

#### 3. Add Environment Variables

In `.env.example`:
```env
# Service Name Configuration
SERVICE_PORT=7777
SERVICE_USER=admin
SERVICE_PASSWORD=changeme123_service
SERVICE_API_KEY=generate_random_key_here
```

#### 4. Update Documentation

**In `docs/SERVICES.md`:**

```markdown
### ServiceName
**Description**

| Property | Value |
|----------|-------|
| **Image** | `username/service:tag` |
| **Profile** | `your-profile` |
| **Port** | 7777 |
| **Access** | `https://service.{DOMAIN}` or `http://localhost:7777` |
| **Purpose** | What this service does |

**Configuration:**
- **Username**: Set via `SERVICE_USER`
- **Password**: Set via `SERVICE_PASSWORD`

**Features:**
- Feature 1
- Feature 2
- Feature 3

**First Steps:**
1. Access the UI
2. Complete initial setup
3. Configure settings

**Common Issues:**
- Issue 1: Solution
- Issue 2: Solution
```

**In `README.md`:**

Add to appropriate profile table:
```markdown
| Profile | Services | Use Case | RAM |
|---------|----------|----------|-----|
| **your-profile** | ServiceName, Others | Purpose | Memory |
```

#### 5. Update Setup Script

In `scripts/setup.sh`, add directory creation:

```bash
# In create_directories() function
local services=(
    # ... existing services ...
    "your-service"
)
```

#### 6. Test Your Service

```bash
# Validate syntax
docker compose config

# Test service alone
docker compose --profile your-profile up -d your-service

# Check logs
docker compose logs -f your-service

# Test access
curl -I http://localhost:7777

# Test with other services
docker compose --profile your-profile up -d

# Run health check
./scripts/health-check.sh
```

---

## 🏷️ Creating Profiles

### Profile Best Practices

**Good Profile Design:**
- Group related services
- Consider dependencies
- Aim for 3-8 services per profile
- Use clear, descriptive names

**Profile Naming:**
- Lowercase
- Descriptive (purpose-based)
- Single word preferred
- Examples: `media`, `monitoring`, `iot`

### Creating a New Profile

#### 1. Define Profile Purpose

Example: Create a "gaming" profile for game servers

Services needed:
- Minecraft server
- Terraria server
- Game server dashboard

#### 2. Add Services with Profile

```yaml
services:
  minecraft:
    image: itzg/minecraft-server
    # ... configuration ...
    profiles: ["gaming", "all"]
    
  terraria:
    image: ryshe/terraria
    # ... configuration ...
    profiles: ["gaming", "all"]
    
  gamesdb:
    image: linuxserver/heimdall  # Or custom dashboard
    # ... configuration ...
    profiles: ["gaming", "all"]
```

#### 3. Document Profile

**In `README.md`:**

```markdown
### 🎮 Gaming Profiles

| Profile | Services | Use Case | RAM |
|---------|----------|----------|-----|
| **gaming** | Minecraft, Terraria, GamesDashboard | Game servers | 4GB |
```

#### 4. Update Setup Script

```bash
# In show_service_menu() function
echo "  13. Gaming Servers (minecraft, terraria)"

# In get_selection() function
12) echo "gaming" ;;
```

### Profile Dependencies

Handle service dependencies:

```yaml
services:
  web-app:
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    profiles: ["webapp"]
    
  postgres:
    # ... config ...
    profiles: ["databases", "webapp", "all"]
    
  redis:
    # ... config ...
    profiles: ["databases", "webapp", "all"]
```

---

## 📝 Documentation Guidelines

### Documentation Standards

**Every new service needs:**
1. Entry in `docs/SERVICES.md`
2. Mention in appropriate `README.md` section
3. Environment variables in `.env.example`
4. Common issues in `docs/TROUBLESHOOTING.md`

### Writing Style

**Do:**
- ✅ Use clear, simple language
- ✅ Include code examples
- ✅ Provide step-by-step instructions
- ✅ Use tables for structured data
- ✅ Add troubleshooting sections

**Don't:**
- ❌ Use jargon without explanation
- ❌ Assume prior knowledge
- ❌ Skip error cases
- ❌ Forget to update related docs

### Documentation Template

```markdown
## Service Name

### Overview
Brief description of what the service does.

### Configuration

| Property | Value |
|----------|-------|
| **Image** | `image:tag` |
| **Profile** | `profile-name` |
| **Port** | 1234 |
| **Access** | URLs |

### Environment Variables

```env
SERVICE_VAR=value
SERVICE_PASSWORD=changeme
```

### First-Time Setup

1. Step one
2. Step two
3. Step three

### Common Use Cases

**Use Case 1:**
Description and instructions

**Use Case 2:**
Description and instructions

### Troubleshooting

**Issue 1:**
- Symptoms
- Diagnosis
- Solution

**Issue 2:**
- Symptoms
- Diagnosis
- Solution

### Related Services

- Service A: How it relates
- Service B: How it relates
```

---

## 🧪 Testing

### Pre-Commit Checklist

Before committing:

- [ ] YAML syntax valid (`docker compose config`)
- [ ] Shell scripts pass shellcheck
- [ ] Documentation updated
- [ ] `.env.example` updated
- [ ] Services start successfully
- [ ] Health checks pass
- [ ] No sensitive data in commits

### Validation Commands

```bash
# Validate YAML syntax
docker compose config

# Validate YAML formatting
yamllint docker-compose.yml

# Validate shell scripts
shellcheck scripts/*.sh

# Test service startup
docker compose --profile test-profile up -d

# Run health checks
./scripts/health-check.sh

# Check for secrets
git secrets --scan
```

### Testing New Services

```bash
# 1. Clean environment
docker compose down -v

# 2. Start only your service
docker compose --profile your-profile up -d your-service

# 3. Check logs for errors
docker compose logs -f your-service

# 4. Test functionality
curl http://localhost:7777
# Or access in browser

# 5. Test with dependencies
docker compose --profile your-profile up -d

# 6. Test full stack
docker compose --profile all up -d

# 7. Verify health
./scripts/health-check.sh

# 8. Check resources
docker stats --no-stream

# 9. Test restart
docker compose restart your-service
docker compose logs -f your-service
```

### Test Scenarios

**Scenario 1: Fresh Install**
```bash
# Simulate new user experience
rm -rf config/ media/ backups/ .env
cp .env.example .env
./scripts/setup.sh
# Follow prompts and verify
```

**Scenario 2: Service Upgrade**
```bash
# Test upgrade path
docker compose pull your-service
docker compose stop your-service
docker compose up -d your-service
# Verify no data loss
```

**Scenario 3: Network Issues**
```bash
# Test network resilience
docker network disconnect traefik your-service
# Should handle gracefully
docker network connect traefik your-service
# Should recover
```

---

## 🤝 Contributing

### Contribution Types

We welcome:
- 🐛 **Bug Fixes**: Fix issues in existing services
- ✨ **New Services**: Add new containerized applications
- 📝 **Documentation**: Improve or fix docs
- 🔧 **Scripts**: Enhance automation scripts
- 🎨 **UI/UX**: Improve dashboard or configs
- 🧪 **Tests**: Add validation and tests

### Pull Request Process

1. **Create Issue First** (for large changes)
   - Describe what you want to add/change
   - Get feedback before coding

2. **Follow Commit Convention**
   ```
   feat: add ServiceName to profile
   fix: resolve port conflict in Jellyfin
   docs: update networking guide
   chore: update dependencies
   ```

3. **Keep PRs Focused**
   - One feature/fix per PR
   - Separate refactoring from features
   - Include tests if applicable

4. **Update Documentation**
   - Update relevant docs
   - Add to CHANGELOG
   - Update service catalog

5. **Test Thoroughly**
   - Test your changes
   - Include test results in PR
   - Verify no regressions

6. **Request Review**
   - Tag relevant reviewers
   - Respond to feedback
   - Make requested changes

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Breaking change

## Testing
- [ ] Validated YAML syntax
- [ ] Tested service startup
- [ ] Verified health checks
- [ ] Updated documentation
- [ ] No secrets in commits

## Screenshots (if applicable)
Add screenshots of new features

## Checklist
- [ ] Code follows project style
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests pass
```

---

## 🎨 Code Style

### YAML Style

```yaml
# Use 2-space indentation
services:
  service-name:
    image: image:tag
    
# Group related configs
environment:
  VAR1: value1
  VAR2: value2
  
# Comment complex sections
volumes:
  # Application data
  - ${CONFIG_PATH}/service:/config
  # Media library (read-only)
  - ${MEDIA_PATH}:/media:ro
  
# Consistent label formatting
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.name.rule=Host(`example.com`)"
```

### Shell Script Style

```bash
#!/usr/bin/env bash

# Use bash strict mode
set -euo pipefail

# Constants in UPPERCASE
readonly SCRIPT_VERSION="1.0.0"

# Functions use snake_case
function print_header() {
    echo "==================================="
    echo "  $1"
    echo "==================================="
}

# Local variables in lowercase
function process_service() {
    local service_name=$1
    local service_port=$2
    
    # Check before use
    if [[ -z "$service_name" ]]; then
        echo "Error: service name required"
        return 1
    fi
    
    echo "Processing $service_name on port $service_port"
}

# Main execution
main() {
    print_header "Starting Process"
    process_service "jellyfin" "8096"
}

# Run main
main "$@"
```

### Environment Variables

```env
# Group related variables
# ============================================================================
# CORE CONFIGURATION
# ============================================================================
HOMELAB_DOMAIN=lab.example.com
ACCESS_MODE=domain

# ============================================================================
# SERVICE CREDENTIALS
# ============================================================================
POSTGRES_PASSWORD=changeme123_postgres
REDIS_PASSWORD=changeme123_redis

# Use descriptive names
SERVICE_PORT=7777  # Good
PORT=7777          # Avoid

# Provide defaults in compose file
${SERVICE_VAR:-default_value}

# Document expected format
# Format: email@domain.com
TRAEFIK_EMAIL=your@email.com
```

### Documentation Style

```markdown
# Use ATX-style headers (# not underlines)

## Section Header

### Subsection

# Use code blocks with language
```bash
docker compose up -d
```

# Use tables for structured data
| Column 1 | Column 2 |
|----------|----------|
| Value 1  | Value 2  |

# Use checklists for tasks
- [ ] Task 1
- [ ] Task 2
- [x] Completed task

# Use admonitions for important info
> ⚠️ **Warning**: This is important!
> 💡 **Tip**: Helpful suggestion
> ℹ️ **Note**: Additional information
```

---

## 🔍 Code Review Guidelines

### What Reviewers Look For

**Functionality:**
- Does it work as intended?
- Are there edge cases?
- Error handling present?

**Code Quality:**
- Follows project style?
- Well commented?
- No code duplication?

**Documentation:**
- All docs updated?
- Examples included?
- Troubleshooting added?

**Testing:**
- Adequate testing?
- Test results provided?
- No regressions?

### Reviewer Checklist

```markdown
- [ ] Code follows style guidelines
- [ ] Documentation is complete
- [ ] No secrets or sensitive data
- [ ] YAML is valid
- [ ] Service starts successfully
- [ ] Health checks work
- [ ] Labels are correct (if using Traefik)
- [ ] Environment variables documented
- [ ] Profiles are appropriate
- [ ] Dependencies are specified
- [ ] Commit messages follow convention
```

---

## 📚 Additional Resources

### Learning Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [YAML Syntax Guide](https://yaml.org/spec/)
- [Markdown Guide](https://www.markdownguide.org/)

### Community

- [r/selfhosted](https://reddit.com/r/selfhosted)
- [r/homelab](https://reddit.com/r/homelab)
- [Docker Community](https://www.docker.com/community/)

### Tools

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [VS Code](https://code.visualstudio.com/)
- [yamllint](https://github.com/adrienverge/yamllint)
- [shellcheck](https://www.shellcheck.net/)
- [hadolint](https://github.com/hadolint/hadolint) (Dockerfile linting)

---

## 🎉 Thank You!

Thank you for contributing to this project! Your efforts help make self-hosting accessible to everyone.

### Recognition

Contributors are recognized in:
- README.md Contributors section
- Release notes
- Project documentation

### Questions?

- **Issues**: [GitHub Issues](https://github.com/r-o-k-u/Homelab/issues)
- **Discussions**: [GitHub Discussions](https://github.com/r-o-k-u/Homelab/discussions)
- **Email**: Via GitHub profile

---

[⬅ Back to Main README](../README.md)