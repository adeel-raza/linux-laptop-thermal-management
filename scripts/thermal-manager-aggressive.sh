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
UNLOCK_TEMP_THRESHOLD=60      # And temp <60°C

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
