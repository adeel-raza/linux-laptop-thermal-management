#!/bin/bash

###############################################################################
# Linux Laptop Thermal Management - One-Command Quick Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/USERNAME/linux-laptop-thermal-management/main/quick-install.sh | sudo bash
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Linux Laptop Thermal Management - Quick Installer${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Detect if being piped from curl
if [ -t 0 ]; then
    # Running from file
    INSTALL_MODE="local"
else
    # Being piped from curl
    INSTALL_MODE="remote"
fi

echo -e "${YELLOW}Installing dependencies...${NC}"

# Check and install lm-sensors
if ! command -v sensors &> /dev/null; then
    echo "Installing lm-sensors..."
    apt-get update -qq && apt-get install -y lm-sensors > /dev/null 2>&1
    echo -e "${GREEN}✓ Installed lm-sensors${NC}"
else
    echo -e "${GREEN}✓ lm-sensors already installed${NC}"
fi

echo ""
echo -e "${YELLOW}Downloading thermal management script...${NC}"

# Download the aggressive thermal manager script
curl -fsSL https://raw.githubusercontent.com/USERNAME/linux-laptop-thermal-management/main/scripts/thermal-manager-aggressive.sh > /usr/local/bin/thermal-manager.sh
chmod +x /usr/local/bin/thermal-manager.sh
echo -e "${GREEN}✓ Downloaded thermal manager script${NC}"

echo ""
echo -e "${YELLOW}Creating systemd service...${NC}"

# Create systemd service
cat > /etc/systemd/system/thermal-manager.service << 'EOF'
[Unit]
Description=Linux Laptop Thermal Management (Aggressive)
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/thermal-manager.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable thermal-manager.service > /dev/null 2>&1
systemctl start thermal-manager.service
echo -e "${GREEN}✓ Service enabled and started${NC}"

echo ""
echo -e "${YELLOW}Downloading monitoring script...${NC}"

# Download monitoring script
curl -fsSL https://raw.githubusercontent.com/USERNAME/linux-laptop-thermal-management/main/scripts/monitor-laptop-temps.sh > /usr/local/bin/monitor-laptop-temps
chmod +x /usr/local/bin/monitor-laptop-temps
echo -e "${GREEN}✓ Monitoring script installed${NC}"

# Optional: Dell BIOS mode
if command -v smbios-thermal-ctl &> /dev/null; then
    echo ""
    echo -e "${YELLOW}Dell laptop detected!${NC}"
    read -p "Set BIOS to Performance mode? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Create BIOS setter script
        cat > /usr/local/bin/set-bios-performance.sh << 'EOF'
#!/bin/bash
smbios-thermal-ctl --set-thermal-mode=performance > /dev/null 2>&1 || true
EOF
        chmod +x /usr/local/bin/set-bios-performance.sh
        
        # Create service
        cat > /etc/systemd/system/bios-thermal-mode.service << 'EOF'
[Unit]
Description=Set Dell BIOS to Performance Thermal Mode
After=multi-user.target
Before=thermal-manager.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set-bios-performance.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable bios-thermal-mode.service > /dev/null 2>&1
        systemctl start bios-thermal-mode.service
        echo -e "${GREEN}✓ BIOS Performance mode enabled${NC}"
    fi
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Installation Complete! 🎉${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Thermal management is now active and will persist across reboots."
echo ""
echo -e "${BLUE}To monitor temperatures:${NC}"
echo -e "  monitor-laptop-temps"
echo ""
echo -e "${BLUE}To check service status:${NC}"
echo -e "  sudo systemctl status thermal-manager.service"
echo ""
echo -e "${BLUE}To view logs:${NC}"
echo -e "  sudo tail -f /var/log/thermal-manager.log"
echo ""
echo -e "${YELLOW}Expected results:${NC}"
echo -e "  • Peak temps: 66-75°C (down from 90°C+)"
echo -e "  • Average temps: 50-60°C during work"
echo -e "  • 3.8 GHz turbo bursts for snappy response"
echo -e "  • 2.6 GHz cap during sustained load"
echo -e "  • Laptop bottom: comfortable ✓"
echo ""
echo -e "${BLUE}GitHub:${NC} https://github.com/USERNAME/linux-laptop-thermal-management"
echo ""

