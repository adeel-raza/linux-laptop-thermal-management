#!/bin/bash
# Apply Option C (Relaxed Middle-Ground) - RECOMMENDED configuration

THERMAL_SCRIPT="/home/adeel/linux-laptop-thermal-management/scripts/thermal-manager-aggressive.sh"

echo "═══════════════════════════════════════════════════════════"
echo "   Applying Option C (Relaxed Middle-Ground)"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "This configuration provides:"
echo "  ✓ Best average performance (1.73 GHz avg)"
echo "  ✓ Comfortable temperatures (63-73°C max)"
echo "  ✓ Optimal balance for daily use"
echo ""

# Apply settings
echo "► Updating thermal thresholds..."
sudo sed -i 's/^PREDICT_CPU_THRESHOLD=.*/PREDICT_CPU_THRESHOLD=75/' "$THERMAL_SCRIPT"
sudo sed -i 's/^PREDICT_TEMP_THRESHOLD=.*/PREDICT_TEMP_THRESHOLD=67/' "$THERMAL_SCRIPT"
sudo sed -i 's/^EMERGENCY_TEMP=.*/EMERGENCY_TEMP=75/' "$THERMAL_SCRIPT"
sudo sed -i 's/^UNLOCK_TEMP_THRESHOLD=.*/UNLOCK_TEMP_THRESHOLD=64/' "$THERMAL_SCRIPT"

echo ""
echo "► Restarting thermal-manager.service..."
sudo systemctl restart thermal-manager.service

if systemctl is-active --quiet thermal-manager.service; then
    echo ""
    echo "✓ Option C (Relaxed Middle-Ground) applied successfully!"
    echo ""
    echo "New Configuration:"
    grep -E "^(PREDICT_CPU_THRESHOLD|PREDICT_TEMP_THRESHOLD|EMERGENCY_TEMP)=" "$THERMAL_SCRIPT" | sed 's/^/  /'
    echo ""
    echo "Your system is now optimized for the perfect balance!"
    echo "Monitor with: /home/adeel/monitor-laptop-temps.sh"
else
    echo ""
    echo "✗ Failed to restart thermal-manager.service"
    echo "Check logs with: sudo journalctl -u thermal-manager.service -n 50"
    exit 1
fi

