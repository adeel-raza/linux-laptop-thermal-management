#!/bin/bash

###############################################################################
# AGGRESSIVE Thermal Management: Fast Polling + Continuous Enforcement
# Catch spikes BEFORE they reach 80°C+
###############################################################################

echo "════════════════════════════════════════════════════════════"
echo "   AGGRESSIVE THERMAL MANAGEMENT"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "Previous script problems:"
echo "  ✗ Checked every 0.5s (too slow for instant spikes)"
echo "  ✗ Locked at CPU >60% (missed rapid transitions)"
echo "  ✗ Single enforcement per cycle (race conditions)"
echo ""
echo "New aggressive approach:"
echo "  ✓ Check every 0.1s (10x faster reaction)"
echo "  ✓ Lock at CPU >50% (catch earlier)"
echo "  ✓ Continuously enforce lock (prevent races)"
echo "  ✓ Still allow 3.8 GHz for quick tasks"
echo ""

# Create the AGGRESSIVE thermal management script
cat > /tmp/thermal-manager.sh << 'THERMAL_EOF'
#!/bin/bash

# AGGRESSIVE thermal management with fast polling
# Goal: Catch spikes BEFORE they hit 80°C+

LOG_FILE="/var/log/thermal-manager.log"
STATE_FILE="/tmp/thermal-manager-state"
MAX_SUSTAINED_FREQ="2600000"  # 2.6 GHz (safe sustained)
MAX_BURST_FREQ="3800000"      # 3.8 GHz (turbo)

# AGGRESSIVE predictive thresholds
PREDICT_CPU_THRESHOLD=50      # Lock at CPU >50% (earlier than before)
PREDICT_TEMP_THRESHOLD=58     # Lock if temp >58°C

# REACTIVE emergency threshold
EMERGENCY_TEMP=65             # Force lock at 65°C (earlier than before)

# UNLOCK thresholds
UNLOCK_CPU_THRESHOLD=35       # Unlock when CPU drops <35%
UNLOCK_TEMP_THRESHOLD=56      # And temp <56°C

# Fast polling for quick reaction
CHECK_INTERVAL=0.1            # Check every 0.1s (10 times per second)

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

get_cpu_temp() {
    local temp=$(sensors 2>/dev/null | grep -i "package id 0" | awk '{print $4}' | sed 's/+//;s/°C//' | cut -d'.' -f1)
    if [ -z "$temp" ]; then
        echo "50"
    else
        echo "$temp"
    fi
}

get_cpu_usage() {
    local usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print int(usage)}')
    if [ -z "$usage" ]; then
        echo "0"
    else
        echo "$usage"
    fi
}

get_current_max_freq() {
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || echo "3800000"
}

set_max_freq() {
    local freq=$1
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
        echo "$freq" > "$cpu" 2>/dev/null
    done
}

is_locked() {
    [ -f "$STATE_FILE" ] && [ "$(cat $STATE_FILE)" = "locked" ]
}

lock_frequency() {
    local reason=$1
    local temp=$2
    local cpu=$3
    
    # Only log if state is changing
    if ! is_locked; then
        echo "locked" > "$STATE_FILE"
        log_message "🔒 LOCKED to 2.6 GHz ($reason: temp=${temp}°C, CPU=${cpu}%)"
    fi
    
    # ALWAYS enforce lock (prevent race conditions)
    set_max_freq "$MAX_SUSTAINED_FREQ"
}

unlock_frequency() {
    local temp=$1
    local cpu=$2
    
    # Only log if state is changing
    if is_locked; then
        echo "unlocked" > "$STATE_FILE"
        log_message "🔓 UNLOCKED to 3.8 GHz (temp=${temp}°C, CPU=${cpu}%)"
    fi
    
    # Set frequency
    set_max_freq "$MAX_BURST_FREQ"
}

log_message "Thermal manager started (AGGRESSIVE: 0.1s polling, CPU >50% lock)"

# Initialize state - start unlocked
echo "unlocked" > "$STATE_FILE"

while true; do
    temp=$(get_cpu_temp)
    cpu_usage=$(get_cpu_usage)
    current_max=$(get_current_max_freq)
    
    if is_locked; then
        # Currently LOCKED - check if we can safely unlock
        if [ "$cpu_usage" -lt "$UNLOCK_CPU_THRESHOLD" ] && [ "$temp" -lt "$UNLOCK_TEMP_THRESHOLD" ]; then
            unlock_frequency "$temp" "$cpu_usage"
        else
            # CONTINUOUSLY enforce lock every cycle (prevent race conditions)
            if [ "$current_max" -gt "$MAX_SUSTAINED_FREQ" ]; then
                set_max_freq "$MAX_SUSTAINED_FREQ"
            fi
        fi
    else
        # Currently UNLOCKED - check if we should lock
        
        # EMERGENCY: Temp getting hot
        if [ "$temp" -ge "$EMERGENCY_TEMP" ]; then
            lock_frequency "EMERGENCY" "$temp" "$cpu_usage"
        
        # PREDICTIVE: Moderate CPU + warming = lock early
        elif [ "$cpu_usage" -ge "$PREDICT_CPU_THRESHOLD" ] && [ "$temp" -ge "$PREDICT_TEMP_THRESHOLD" ]; then
            lock_frequency "PREDICTIVE" "$temp" "$cpu_usage"
        
        # PREDICTIVE: High CPU alone (likely sustained work)
        elif [ "$cpu_usage" -ge 75 ]; then
            lock_frequency "HIGH_CPU" "$temp" "$cpu_usage"
        fi
    fi
    
    sleep $CHECK_INTERVAL
done
THERMAL_EOF

sudo mv /tmp/thermal-manager.sh /usr/local/bin/thermal-manager.sh
sudo chmod +x /usr/local/bin/thermal-manager.sh

echo "✓ Aggressive script created"
echo ""

echo "Key improvements:"
echo ""
echo "1. FASTER POLLING:"
echo "   • Checks every 0.1s (was 0.5s)"
echo "   • 10x faster reaction to CPU spikes"
echo ""
echo "2. EARLIER LOCKING:"
echo "   • Locks at CPU >50% (was >60%)"
echo "   • Locks at temp >58°C (was >60°C)"
echo "   • Emergency at 65°C (was 68°C)"
echo ""
echo "3. CONTINUOUS ENFORCEMENT:"
echo "   • Re-applies frequency cap every 0.1s"
echo "   • Prevents race conditions with kernel"
echo ""
echo "4. STILL ALLOWS BURSTS:"
echo "   • Brief tasks <35% CPU get 3.8 GHz"
echo "   • Maintains Windows-like responsiveness"
echo ""

echo "Restarting thermal manager..."
sudo systemctl restart thermal-manager.service

sleep 2

echo ""
echo "════════════════════════════════════════════════════════════"
echo "   SERVICE STATUS"
echo "════════════════════════════════════════════════════════════"
echo ""
sudo systemctl status thermal-manager.service --no-pager -l | head -20
echo ""

echo "════════════════════════════════════════════════════════════"
echo "   EXPECTED RESULTS"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Before (hybrid script):"
echo "  • Brief spikes to 80-84°C"
echo "  • Reaction time: 0.5s"
echo ""
echo "After (aggressive script):"
echo "  • Should catch spikes at 65-70°C max"
echo "  • Reaction time: 0.1s"
echo ""
echo "Trade-off:"
echo "  • Slightly more frequent locking"
echo "  • But still allows 3.8 GHz for light work"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "   TEST IT"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Run the monitor:"
echo "  ./monitor-laptop-temps.sh"
echo ""
echo "Watch for those background spikes - they should now be"
echo "caught at 65-70°C instead of 80-84°C!"
echo ""

