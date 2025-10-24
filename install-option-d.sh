#!/bin/bash

# Simple One-Command Installation for Option D (Recommended)
# This is the optimal configuration: 3.5 GHz max, balanced thermal management

set -e

echo "════════════════════════════════════════════════════════"
echo "  Dell Laptop Thermal Management - Option D Installer"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Installing the RECOMMENDED configuration:"
echo "  • Max CPU: 3.5 GHz (Conservative Turbo)"
echo "  • Governor: powersave (battery efficient)"
echo "  • Thermal: Balanced (70°C threshold)"
echo "  • Expected temps: 50-75°C max"
echo ""

# Check for root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo:"
    echo "  sudo bash install-option-d.sh"
    exit 1
fi

# Install thermal manager
echo "📦 Installing thermal manager..."
cp /tmp/thermal-manager-option-d-fixed.sh /usr/local/bin/thermal-manager.sh
chmod +x /usr/local/bin/thermal-manager.sh

# Create thermal manager service if it doesn't exist
if [ ! -f /etc/systemd/system/thermal-manager.service ]; then
    echo "📦 Creating thermal manager service..."
    cat > /etc/systemd/system/thermal-manager.service << 'EOFSERVICE'
[Unit]
Description=Thermal Management Service (Option D)
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/thermal-manager.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOFSERVICE
fi

# Create governor service
echo "📦 Setting up powersave governor..."
cp /tmp/set-governor.service /etc/systemd/system/set-governor.service

# Reload systemd
systemctl daemon-reload

# Enable and start services
echo "🚀 Enabling services..."
systemctl enable thermal-manager.service
systemctl enable set-governor.service

echo "🔄 Starting services..."
systemctl restart thermal-manager.service
systemctl restart set-governor.service

# Verify
sleep 2
CURRENT_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)
CURRENT_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✅ Installation Complete!"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Current Configuration:"
echo "  Max Frequency: $(echo "scale=1; $CURRENT_FREQ / 1000000" | bc) GHz"
echo "  Governor: $CURRENT_GOV"
echo ""
echo "Services Status:"
systemctl is-active thermal-manager.service && echo "  ✓ Thermal Manager: Running" || echo "  ✗ Thermal Manager: Failed"
systemctl is-active set-governor.service && echo "  ✓ Governor Service: Active" || echo "  ✗ Governor Service: Failed"
echo ""
echo "This configuration will persist after reboot! 🎉"
echo ""
echo "To monitor your system:"
echo "  ~/monitor-laptop-temps.sh"
echo ""

