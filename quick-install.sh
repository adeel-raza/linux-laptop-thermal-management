#!/bin/bash

###############################################################################
# Linux Laptop Thermal Management - One-Command Quick Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/adeel-raza/linux-laptop-thermal-management/main/quick-install.sh | sudo bash
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
curl -fsSL https://raw.githubusercontent.com/adeel-raza/linux-laptop-thermal-management/main/scripts/thermal-manager-aggressive.sh > /usr/local/bin/thermal-manager.sh
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
curl -fsSL https://raw.githubusercontent.com/adeel-raza/linux-laptop-thermal-management/main/scripts/monitor-laptop-temps.sh > /usr/local/bin/monitor-laptop-temps
chmod +x /usr/local/bin/monitor-laptop-temps
echo -e "${GREEN}✓ Monitoring script installed${NC}"

echo ""
echo -e "${YELLOW}Installing configuration management tools...${NC}"

# Download configuration switcher
curl -fsSL https://raw.githubusercontent.com/adeel-raza/linux-laptop-thermal-management/main/scripts/switch-thermal-config.sh > /usr/local/bin/switch-thermal-config.sh
chmod +x /usr/local/bin/switch-thermal-config.sh
echo -e "${GREEN}✓ Configuration switcher installed${NC}"

# Download Option C quick-apply script
curl -fsSL https://raw.githubusercontent.com/adeel-raza/linux-laptop-thermal-management/main/scripts/apply-option-c.sh > /usr/local/bin/apply-option-c.sh
chmod +x /usr/local/bin/apply-option-c.sh
echo -e "${GREEN}✓ Quick configuration tools installed${NC}"

echo ""
echo -e "${YELLOW}Applying recommended configuration (Option C)...${NC}"

# Set Option C thresholds (Relaxed Middle-Ground - Recommended)
sed -i 's/^PREDICT_CPU_THRESHOLD=.*/PREDICT_CPU_THRESHOLD=75/' /usr/local/bin/thermal-manager.sh
sed -i 's/^PREDICT_TEMP_THRESHOLD=.*/PREDICT_TEMP_THRESHOLD=67/' /usr/local/bin/thermal-manager.sh
sed -i 's/^EMERGENCY_TEMP=.*/EMERGENCY_TEMP=75/' /usr/local/bin/thermal-manager.sh
sed -i 's/^UNLOCK_TEMP_THRESHOLD=.*/UNLOCK_TEMP_THRESHOLD=64/' /usr/local/bin/thermal-manager.sh

# Restart service to apply new configuration
systemctl restart thermal-manager.service
echo -e "${GREEN}✓ Option C (Relaxed Middle-Ground) configured${NC}"

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
echo -e "Thermal management is now active with ${BLUE}Option C (Recommended)${NC}"
echo -e "This configuration provides the best balance of performance and comfort."
echo ""
echo -e "${BLUE}Monitor your system:${NC}"
echo -e "  monitor-laptop-temps"
echo ""
echo -e "${BLUE}Switch configurations (optional):${NC}"
echo -e "  sudo switch-thermal-config.sh"
echo -e "  ${YELLOW}Options: A (Coolest), B (Max Performance), C (Best Balance)${NC}"
echo ""
echo -e "${BLUE}Check service status:${NC}"
echo -e "  sudo systemctl status thermal-manager.service"
echo ""
echo -e "${YELLOW}Expected results with Option C:${NC}"
echo -e "  • Idle temps: 48-55°C ❄️"
echo -e "  • Normal work: 50-65°C ✅"
echo -e "  • Heavy load: 60-75°C ✅"
echo -e "  • Full 3.8 GHz turbo bursts available"
echo -e "  • 10% faster than conservative mode"
echo -e "  • Laptop bottom: comfortable 90%+ of time ✓"
echo ""
echo -e "${YELLOW}Brief 75-85°C spikes are normal and harmless!${NC}"
echo -e "  They last <5 seconds and mean your turbo boost is working."
echo ""
echo -e "${BLUE}GitHub:${NC} https://github.com/adeel-raza/linux-laptop-thermal-management"
echo -e "${BLUE}Test Results:${NC} See TEST_RESULTS.md for detailed performance comparison"
echo ""



