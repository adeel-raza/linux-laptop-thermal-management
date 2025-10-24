#!/bin/bash
# Quick thermal configuration switcher

THERMAL_SCRIPT="/home/adeel/linux-laptop-thermal-management/scripts/thermal-manager-aggressive.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   THERMAL CONFIGURATION SWITCHER${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Show current configuration
echo -e "${CYAN}Current Configuration:${NC}"
grep -E "^(PREDICT_CPU_THRESHOLD|PREDICT_TEMP_THRESHOLD|EMERGENCY_TEMP)=" "$THERMAL_SCRIPT" | sed 's/^/  /'
echo ""

# Show menu
echo "Available Configurations:"
echo ""
echo -e "${GREEN}[A]${NC} Middle-Ground (Cool & Conservative)"
echo "    → Max Temp: ~62-65°C  |  Avg Freq: 1.57 GHz"
echo "    → Best for: Maximum thermal comfort"
echo "    → Settings: CPU>60%, Temp>62°C"
echo ""
echo -e "${YELLOW}[B]${NC} Full Turbo Balanced (Max Performance)"
echo "    → Max Temp: ~65-83°C  |  Avg Freq: 1.62 GHz"
echo "    → Best for: Maximum performance, tolerates warm spikes"
echo "    → Settings: CPU>70%, Temp>65°C"
echo ""
echo -e "${CYAN}[C]${NC} Relaxed Middle-Ground ⭐ RECOMMENDED"
echo "    → Max Temp: ~63-73°C  |  Avg Freq: 1.73 GHz (BEST)"
echo "    → Best for: Optimal balance of performance & comfort"
echo "    → Settings: CPU>75%, Temp>67°C"
echo ""

read -p "Select configuration [A/B/C] or [Q] to quit: " choice

case "${choice^^}" in
    A)
        echo -e "\n${YELLOW}► Applying Option A (Middle-Ground)...${NC}"
        sudo sed -i 's/^PREDICT_CPU_THRESHOLD=.*/PREDICT_CPU_THRESHOLD=60/' "$THERMAL_SCRIPT"
        sudo sed -i 's/^PREDICT_TEMP_THRESHOLD=.*/PREDICT_TEMP_THRESHOLD=62/' "$THERMAL_SCRIPT"
        sudo sed -i 's/^EMERGENCY_TEMP=.*/EMERGENCY_TEMP=68/' "$THERMAL_SCRIPT"
        sudo sed -i 's/^UNLOCK_TEMP_THRESHOLD=.*/UNLOCK_TEMP_THRESHOLD=60/' "$THERMAL_SCRIPT"
        CONFIG_NAME="Option A (Middle-Ground)"
        ;;
    B)
        echo -e "\n${YELLOW}► Applying Option B (Full Turbo Balanced)...${NC}"
        sudo sed -i 's/^PREDICT_CPU_THRESHOLD=.*/PREDICT_CPU_THRESHOLD=70/' "$THERMAL_SCRIPT"
        sudo sed -i 's/^PREDICT_TEMP_THRESHOLD=.*/PREDICT_TEMP_THRESHOLD=65/' "$THERMAL_SCRIPT"
        sudo sed -i 's/^EMERGENCY_TEMP=.*/EMERGENCY_TEMP=70/' "$THERMAL_SCRIPT"
        sudo sed -i 's/^UNLOCK_TEMP_THRESHOLD=.*/UNLOCK_TEMP_THRESHOLD=62/' "$THERMAL_SCRIPT"
        CONFIG_NAME="Option B (Full Turbo Balanced)"
        ;;
    C)
        echo -e "\n${YELLOW}► Applying Option C (Relaxed Middle-Ground)...${NC}"
        sudo sed -i 's/^PREDICT_CPU_THRESHOLD=.*/PREDICT_CPU_THRESHOLD=75/' "$THERMAL_SCRIPT"
        sudo sed -i 's/^PREDICT_TEMP_THRESHOLD=.*/PREDICT_TEMP_THRESHOLD=67/' "$THERMAL_SCRIPT"
        sudo sed -i 's/^EMERGENCY_TEMP=.*/EMERGENCY_TEMP=75/' "$THERMAL_SCRIPT"
        sudo sed -i 's/^UNLOCK_TEMP_THRESHOLD=.*/UNLOCK_TEMP_THRESHOLD=64/' "$THERMAL_SCRIPT"
        CONFIG_NAME="Option C (Relaxed Middle-Ground)"
        ;;
    Q)
        echo -e "\n${CYAN}No changes made. Exiting...${NC}"
        exit 0
        ;;
    *)
        echo -e "\n${RED}Invalid selection. Exiting...${NC}"
        exit 1
        ;;
esac

# Restart thermal manager
echo -e "${YELLOW}Restarting thermal-manager.service...${NC}"
sudo systemctl restart thermal-manager.service

if systemctl is-active --quiet thermal-manager.service; then
    echo -e "${GREEN}✓ $CONFIG_NAME applied successfully!${NC}"
    echo ""
    echo -e "${CYAN}New Configuration:${NC}"
    grep -E "^(PREDICT_CPU_THRESHOLD|PREDICT_TEMP_THRESHOLD|EMERGENCY_TEMP)=" "$THERMAL_SCRIPT" | sed 's/^/  /'
    echo ""
    echo -e "${GREEN}Monitor your system with:${NC} /home/adeel/monitor-laptop-temps.sh"
else
    echo -e "${RED}✗ Failed to restart thermal-manager.service${NC}"
    exit 1
fi

