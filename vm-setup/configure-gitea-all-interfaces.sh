#!/bin/bash

################################################################################
# Configure Gitea to Listen on All Network Interfaces
################################################################################
# This script modifies Gitea's app.ini to listen on 0.0.0.0:3000 instead of
# 127.0.0.1:3000, making it accessible from other machines on the network.
#
# Usage:
#   sudo ./configure-gitea-all-interfaces.sh
#
# What it does:
#   1. Backs up current app.ini
#   2. Changes HTTP_ADDR from 127.0.0.1 to 0.0.0.0
#   3. Restarts Gitea service
#   4. Verifies the change
#   5. Opens firewall port 3000 if needed
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITEA_CONFIG="/etc/gitea/app.ini"
BACKUP_DIR="/etc/gitea/backups"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Configure Gitea - All Network Interfaces${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: This script must be run as root${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

# Check if Gitea config exists
if [ ! -f "$GITEA_CONFIG" ]; then
    echo -e "${RED}ERROR: Gitea configuration not found at $GITEA_CONFIG${NC}"
    echo "Is Gitea installed?"
    exit 1
fi

echo -e "${YELLOW}Step 1: Backing up current configuration${NC}"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/app.ini.$(date +%Y%m%d_%H%M%S)"
cp "$GITEA_CONFIG" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"
echo ""

echo -e "${YELLOW}Step 2: Checking current HTTP_ADDR setting${NC}"
CURRENT_ADDR=$(grep "^HTTP_ADDR" "$GITEA_CONFIG" | cut -d'=' -f2 | tr -d ' ')
echo "Current HTTP_ADDR: $CURRENT_ADDR"
echo ""

if [ "$CURRENT_ADDR" = "0.0.0.0" ]; then
    echo -e "${GREEN}✓ Gitea is already configured to listen on all interfaces${NC}"
    echo ""
else
    echo -e "${YELLOW}Step 3: Updating HTTP_ADDR to 0.0.0.0${NC}"
    
    # Update HTTP_ADDR in [server] section
    sed -i 's/^HTTP_ADDR.*=.*/HTTP_ADDR = 0.0.0.0/' "$GITEA_CONFIG"
    
    # Verify the change
    NEW_ADDR=$(grep "^HTTP_ADDR" "$GITEA_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    if [ "$NEW_ADDR" = "0.0.0.0" ]; then
        echo -e "${GREEN}✓ Configuration updated successfully${NC}"
        echo "New HTTP_ADDR: $NEW_ADDR"
    else
        echo -e "${RED}ERROR: Failed to update configuration${NC}"
        echo "Restoring backup..."
        cp "$BACKUP_FILE" "$GITEA_CONFIG"
        exit 1
    fi
    echo ""
fi

echo -e "${YELLOW}Step 4: Restarting Gitea service${NC}"
systemctl restart gitea
sleep 3

if systemctl is-active --quiet gitea; then
    echo -e "${GREEN}✓ Gitea service restarted successfully${NC}"
else
    echo -e "${RED}ERROR: Gitea service failed to start${NC}"
    echo "Restoring backup..."
    cp "$BACKUP_FILE" "$GITEA_CONFIG"
    systemctl restart gitea
    exit 1
fi
echo ""

echo -e "${YELLOW}Step 5: Verifying Gitea is listening on all interfaces${NC}"
sleep 2
if netstat -tlnp 2>/dev/null | grep -q "0.0.0.0:3000.*gitea" || ss -tlnp 2>/dev/null | grep -q "0.0.0.0:3000.*gitea"; then
    echo -e "${GREEN}✓ Gitea is now listening on 0.0.0.0:3000${NC}"
else
    echo -e "${YELLOW}⚠ Could not verify listening status with netstat/ss${NC}"
    echo "Checking with systemctl status..."
    systemctl status gitea --no-pager | head -20
fi
echo ""

echo -e "${YELLOW}Step 6: Checking firewall configuration${NC}"
if command -v firewall-cmd &> /dev/null; then
    if firewall-cmd --list-ports | grep -q "3000/tcp"; then
        echo -e "${GREEN}✓ Firewall already allows port 3000${NC}"
    else
        echo -e "${YELLOW}Opening port 3000 in firewall...${NC}"
        firewall-cmd --permanent --add-port=3000/tcp
        firewall-cmd --reload
        echo -e "${GREEN}✓ Port 3000 opened in firewall${NC}"
    fi
else
    echo -e "${YELLOW}⚠ firewalld not found, skipping firewall configuration${NC}"
fi
echo ""

echo -e "${YELLOW}Step 7: Testing connectivity${NC}"
echo "Testing localhost connection..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓ Localhost connection successful${NC}"
else
    echo -e "${YELLOW}⚠ Localhost connection test inconclusive${NC}"
fi

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')
if [ -n "$SERVER_IP" ]; then
    echo ""
    echo "Testing network connection..."
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://$SERVER_IP:3000 | grep -q "200\|301\|302"; then
        echo -e "${GREEN}✓ Network connection successful${NC}"
    else
        echo -e "${YELLOW}⚠ Network connection test inconclusive${NC}"
    fi
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Configuration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Gitea Access Information:${NC}"
echo "  • Localhost:    http://localhost:3000"
if [ -n "$SERVER_IP" ]; then
    echo "  • Network IP:   http://$SERVER_IP:3000"
fi
echo "  • Hostname:     http://$(hostname):3000"
echo ""
echo -e "${BLUE}Configuration Details:${NC}"
echo "  • Config file:  $GITEA_CONFIG"
echo "  • Backup file:  $BACKUP_FILE"
echo "  • HTTP_ADDR:    0.0.0.0"
echo "  • HTTP_PORT:    3000"
echo ""
echo -e "${YELLOW}Note:${NC} If you have Nginx/Caddy reverse proxy, you may want to"
echo "      keep Gitea on localhost (127.0.0.1) for security and access"
echo "      it only through the reverse proxy."
echo ""
echo -e "${YELLOW}To revert:${NC}"
echo "  sudo cp $BACKUP_FILE $GITEA_CONFIG"
echo "  sudo systemctl restart gitea"
echo ""

# Made with Bob
