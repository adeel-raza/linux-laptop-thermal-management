#!/bin/bash

###############################################################################
# HYBRID Thermal Management: Predictive + Reactive
# Best of both worlds: Allow turbo for quick tasks, prevent sustained spikes
###############################################################################

echo "════════════════════════════════════════════════════════════"
echo "   HYBRID THERMAL MANAGEMENT"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "The Problem:"
echo "  ✗ Pure temp-based: Too slow (90°C+ spikes before reaction)"
echo "  ✗ Pure CPU-based: Too aggressive (no quick bursts)"
echo ""
echo "The Solution - HYBRID:"
echo "  ✓ PREDICTIVE: Lock before sustained load gets hot"
echo "  ✓ PERMISSIVE: Allow turbo for brief, light tasks"
echo "  ✓ REACTIVE: Fallback if temp spikes anyway"
echo ""

# Create the HYBRID thermal management script
cat > /tmp/thermal-manager.sh << 'THERMAL_EOF'
#!/bin/bash

# HYBRID thermal management: Predictive + Reactive
# Goal: Windows-like snappiness WITHOUT the 90°C spikes

LOG_FILE="/var/log/thermal-manager.log"
STATE_FILE="/tmp/thermal-manager-state"
MAX_SUSTAINED_FREQ="2600000"  # 2.6 GHz (safe sustained)
MAX_BURST_FREQ="3800000"      # 3.8 GHz (turbo)

# PREDICTIVE thresholds (prevent spikes before they happen)
PREDICT_CPU_THRESHOLD=60      # Lock if CPU >60% (sustained work)
PREDICT_TEMP_THRESHOLD=60     # Consider locking if temp already >60°C

# REACTIVE thresholds (emergency fallback)
EMERGENCY_TEMP=68             # Force lock if we reach this

# UNLOCK thresholds (restore turbo capability)
UNLOCK_CPU_THRESHOLD=30       # Unlock when CPU drops <30%
UNLOCK_TEMP_THRESHOLD=58      # And temp is <58°C

# Timing
CHECK_INTERVAL=0.5            # Check every 0.5s for faster reaction

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
    echo "locked" > "$STATE_FILE"
    set_max_freq "$MAX_SUSTAINED_FREQ"
    log_message "🔒 LOCKED to 2.6 GHz ($reason: temp=${temp}°C, CPU=${cpu}%)"
}

unlock_frequency() {
    local temp=$1
    local cpu=$2
    echo "unlocked" > "$STATE_FILE"
    set_max_freq "$MAX_BURST_FREQ"
    log_message "🔓 UNLOCKED to 3.8 GHz (temp=${temp}°C, CPU=${cpu}% - safe for turbo)"
}

log_message "Thermal manager started (HYBRID: Predictive + Reactive)"

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
            # Enforce lock (prevent external changes)
            if [ "$current_max" -gt "$MAX_SUSTAINED_FREQ" ]; then
                set_max_freq "$MAX_SUSTAINED_FREQ"
            fi
        fi
    else
        # Currently UNLOCKED - check if we should lock
        
        # EMERGENCY REACTIVE: Temp already high!
        if [ "$temp" -ge "$EMERGENCY_TEMP" ]; then
            lock_frequency "EMERGENCY" "$temp" "$cpu_usage"
        
        # PREDICTIVE: High CPU usage + warming up = lock before spike
        elif [ "$cpu_usage" -ge "$PREDICT_CPU_THRESHOLD" ] && [ "$temp" -ge "$PREDICT_TEMP_THRESHOLD" ]; then
            lock_frequency "PREDICTIVE" "$temp" "$cpu_usage"
        
        # PREDICTIVE: Very high CPU usage alone (likely sustained work)
        elif [ "$cpu_usage" -ge 80 ]; then
            lock_frequency "HIGH_CPU" "$temp" "$cpu_usage"
        fi
    fi
    
    sleep $CHECK_INTERVAL
done
THERMAL_EOF

sudo mv /tmp/thermal-manager.sh /usr/local/bin/thermal-manager.sh
sudo chmod +x /usr/local/bin/thermal-manager.sh

echo "✓ Hybrid script created"
echo ""

echo "How it works:"
echo ""
echo "┌─ ALLOW 3.8 GHz TURBO when:"
echo "│  ✓ CPU usage < 30% (quick tasks, UI clicks)"
echo "│  ✓ Temp < 58°C (system is cool)"
echo "│  → Result: Snappy Windows-like responsiveness"
echo ""
echo "┌─ LOCK to 2.6 GHz when:"
echo "│  🔒 CPU >60% AND temp >60°C (sustained work heating up)"
echo "│  🔒 CPU >80% (definitely sustained work)"
echo "│  🔒 Temp reaches 68°C (emergency fallback)"
echo "│  → Result: No 90°C spikes"
echo ""
echo "┌─ UNLOCK back to 3.8 GHz when:"
echo "│  ✓ CPU drops <30% AND temp <58°C"
echo "│  → Result: Ready for next snappy burst"
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
echo "   WHAT YOU SHOULD SEE NOW"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📝 Scenario 1: Opening a file in Cursor"
echo "   CPU: 10% → 40% → 10%"
echo "   Freq: 3.8 GHz burst"
echo "   Temp: 54°C → 58°C"
echo "   Result: ✓ Snappy, no lock needed"
echo ""
echo "📝 Scenario 2: Heavy compilation starting"
echo "   CPU: 10% → 70% → 95%"
echo "   Temp: 54°C → 62°C"
echo "   Freq: Brief 3.8 GHz → 🔒 LOCK to 2.6 GHz (predictive)"
echo "   Temp: Stays 65-70°C (no spike to 90°C!)"
echo ""
echo "📝 Scenario 3: Compilation finishes"
echo "   CPU: 95% → 20%"
echo "   Temp: 70°C → 56°C"
echo "   Freq: 🔓 UNLOCK to 3.8 GHz"
echo "   Result: Ready for next snappy burst"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "   TEST IT NOW"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Run the monitor:"
echo "  ./monitor-laptop-temps.sh"
echo ""
echo "Expected behavior:"
echo "  ✓ See occasional 3.8 GHz spikes during light work"
echo "  ✓ See locks to 2.6 GHz before temp reaches 70°C"
echo "  ✓ No more 90°C spikes"
echo "  ✓ Snappy response + comfortable laptop"
echo ""

