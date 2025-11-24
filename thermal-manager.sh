#!/bin/bash

# Dual-Mode Thermal Manager
# Supports: NORMAL (3.7 GHz) and PERFORMANCE (4.2 GHz single-core / ~3.8 GHz all-core) modes

LOG_FILE="/var/log/thermal-manager.log"
STATE_FILE="/tmp/thermal-manager-state"
MODE_FILE="/etc/thermal-manager-mode"

# Default to NORMAL mode if mode file doesn't exist
if [ -f "$MODE_FILE" ]; then
    MODE=$(cat "$MODE_FILE" | tr '[:lower:]' '[:upper:]')
else
    MODE="NORMAL"
    echo "NORMAL" > "$MODE_FILE"
fi

# Configure based on mode
if [ "$MODE" = "PERFORMANCE" ]; then
    # PERFORMANCE MODE: Maximum CPU utilization - Minimal throttling for peak performance
    # Note: 4.2 GHz allows single-core turbo; all-core naturally caps at ~3.8 GHz
    MAX_SUSTAINED_FREQ="3800000"  # 3.8 GHz (when locked, near max all-core performance)
    MAX_BURST_FREQ="4200000"      # 4.2 GHz (Single-core turbo max; all-core ~3.8 GHz)
    PREDICT_CPU_THRESHOLD=99      # Lock at CPU >99% (virtually never triggers)
    PREDICT_TEMP_THRESHOLD=87     # Lock if temp >87°C (protect from dangerous temps)
    EMERGENCY_TEMP=88             # Force lock at 88°C (protect from 90°C+ spikes)
    UNLOCK_CPU_THRESHOLD=80       # Unlock when CPU <80% (unlock very quickly)
    UNLOCK_TEMP_THRESHOLD=82      # And temp <82°C (unlock when safe)
    HIGH_CPU_THRESHOLD=99         # Extremely high CPU threshold (rarely triggers)
    HIGH_CPU_TEMP_THRESHOLD=87    # Only with very high temp
    MODE_NAME="PERFORMANCE"
else
    # NORMAL MODE: Balanced performance and thermal management
    MAX_SUSTAINED_FREQ="2600000"  # 2.6 GHz (when locked)
    MAX_BURST_FREQ="3700000"      # 3.7 GHz (Balanced turbo)
    PREDICT_CPU_THRESHOLD=75      # Lock at CPU >75%
    PREDICT_TEMP_THRESHOLD=62     # Lock if temp >62°C
    EMERGENCY_TEMP=72             # Force lock at 72°C
    UNLOCK_CPU_THRESHOLD=40       # Unlock when CPU <40%
    UNLOCK_TEMP_THRESHOLD=60      # And temp <60°C
    HIGH_CPU_THRESHOLD=85         # High CPU threshold
    HIGH_CPU_TEMP_THRESHOLD=65    # With elevated temp
    MODE_NAME="NORMAL"
fi

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

set_governor() {
    local gov=$1
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "$gov" > "$cpu" 2>/dev/null
    done
}

set_energy_preference() {
    local pref=$1
    if [ -f /sys/devices/system/cpu/intel_pstate/energy_performance_preference ]; then
        echo "$pref" > /sys/devices/system/cpu/intel_pstate/energy_performance_preference 2>/dev/null
    fi
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
        log_message "🔒 LOCKED to $(echo "scale=1; $MAX_SUSTAINED_FREQ / 1000000" | bc) GHz ($reason: temp=${temp}°C, CPU=${cpu}%)"
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
        log_message "🔓 UNLOCKED to $(echo "scale=1; $MAX_BURST_FREQ / 1000000" | bc) GHz (temp=${temp}°C, CPU=${cpu}%)"
    fi
    
    # Set frequency
    set_max_freq "$MAX_BURST_FREQ"
}

log_message "Thermal manager started (${MODE_NAME} MODE: Max $(echo "scale=1; $MAX_BURST_FREQ / 1000000" | bc) GHz, CPU >${PREDICT_CPU_THRESHOLD}% lock, Emergency at ${EMERGENCY_TEMP}°C)"

# Initialize state - start unlocked with max freq set.
echo "unlocked" > "$STATE_FILE"
set_max_freq "$MAX_BURST_FREQ"

# Set CPU governor based on mode
if [ "$MODE" = "PERFORMANCE" ]; then
    # PERFORMANCE mode: Use performance-oriented governor
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        if grep -q "performance" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null; then
            set_governor "performance"
            log_message "Set CPU governor to 'performance' for maximum responsiveness"
        elif grep -q "schedutil" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null; then
            set_governor "schedutil"
            log_message "Set CPU governor to 'schedutil' for better performance"
        fi
    fi
    # Set energy preference to 'performance' if available
    set_energy_preference "performance"
    # Force higher minimum performance to prevent dropping below 2.5 GHz under load
    # 80% of 4.2 GHz = ~3.4 GHz minimum, ensuring much better sustained performance
    # This prevents Intel P-State from throttling too aggressively under power limits
    if [ -f /sys/devices/system/cpu/intel_pstate/min_perf_pct ]; then
        echo 80 > /sys/devices/system/cpu/intel_pstate/min_perf_pct 2>/dev/null
        log_message "Set Intel P-State min_perf_pct to 80% to prevent 1.7-1.9 GHz cap"
    fi
else
    # NORMAL mode: Use balanced governor (powersave or schedutil)
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        if grep -q "schedutil" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null; then
            set_governor "schedutil"
            log_message "Set CPU governor to 'schedutil' for balanced operation"
        elif grep -q "powersave" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null; then
            set_governor "powersave"
            log_message "Set CPU governor to 'powersave' for balanced operation"
        fi
    fi
    # Set energy preference to 'balance_power' or 'balance_performance' for NORMAL mode
    set_energy_preference "balance_power"
fi

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
        
        # PREDICTIVE: High CPU alone (only if temp is also elevated)
        elif [ "$cpu_usage" -ge "$HIGH_CPU_THRESHOLD" ] && [ "$temp" -ge "$HIGH_CPU_TEMP_THRESHOLD" ]; then
            lock_frequency "HIGH_CPU" "$temp" "$cpu_usage"
        fi
    fi
    
    sleep $CHECK_INTERVAL
done
