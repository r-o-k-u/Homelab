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
