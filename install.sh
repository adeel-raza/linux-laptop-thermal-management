#!/bin/bash

###############################################################################
# Linux Laptop Thermal Management - Automated Installer
# https://github.com/yourusername/linux-laptop-thermal-management
###############################################################################

set -e

echo "═══════════════════════════════════════════════════════════"
echo "   Linux Laptop Thermal Management - Installer"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: This script must be run as root (use sudo)"
    exit 1
fi

# Check dependencies
echo "Checking dependencies..."
MISSING_DEPS=()

if ! command -v sensors &> /dev/null; then
    MISSING_DEPS+=("lm-sensors")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "⚠️  Missing dependencies: ${MISSING_DEPS[*]}"
    echo ""
    read -p "Install missing dependencies? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apt-get update && apt-get install -y "${MISSING_DEPS[@]}"
    else
        echo "❌ Cannot proceed without dependencies"
        exit 1
    fi
fi

echo "✅ All dependencies satisfied"
echo ""

# Install thermal manager script
echo "Installing thermal manager script..."
cp scripts/thermal-manager-aggressive.sh /usr/local/bin/thermal-manager.sh
chmod +x /usr/local/bin/thermal-manager.sh
echo "✅ Installed /usr/local/bin/thermal-manager.sh"

# Install systemd service
echo "Installing systemd service..."
cp systemd/thermal-manager.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable thermal-manager.service
systemctl start thermal-manager.service
echo "✅ Thermal manager service enabled and started"

# Optional: Install BIOS mode persistence (Dell only)
if command -v smbios-thermal-ctl &> /dev/null; then
    echo ""
    read -p "Install Dell BIOS Performance mode persistence? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Create BIOS setter script
        cat > /usr/local/bin/set-bios-performance.sh << 'EOF'
#!/bin/bash
smbios-thermal-ctl --set-thermal-mode=performance > /dev/null 2>&1 || true
EOF
        chmod +x /usr/local/bin/set-bios-performance.sh
        
        # Install service
        cp systemd/bios-thermal-mode.service /etc/systemd/system/
        systemctl daemon-reload
        systemctl enable bios-thermal-mode.service
        systemctl start bios-thermal-mode.service
        echo "✅ BIOS Performance mode will persist across reboots"
    fi
fi

# Install monitoring script
echo ""
echo "Installing monitoring script..."
cp scripts/monitor-laptop-temps.sh /usr/local/bin/
chmod +x /usr/local/bin/monitor-laptop-temps.sh
echo "✅ Installed monitoring script"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "   Installation Complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "✅ Thermal management is now active"
echo ""
echo "To monitor temperatures:"
echo "  monitor-laptop-temps.sh"
echo ""
echo "To check service status:"
echo "  sudo systemctl status thermal-manager.service"
echo ""
echo "To view logs:"
echo "  sudo tail -f /var/log/thermal-manager.log"
echo ""
echo "Expected results:"
echo "  • Peak temps: 66-75°C (down from 90°C+)"
echo "  • Average temps: 50-60°C during work"
echo "  • 3.8 GHz turbo bursts for snappy response"
echo "  • 2.6 GHz cap during sustained load"
echo ""
echo "Reboot recommended (but not required)"
echo ""

