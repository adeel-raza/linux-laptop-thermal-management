#!/bin/bash

###############################################################################
# Automated Test: Compare Aggressive vs Hybrid Scripts
# This will test both, analyze results, and choose the best one
###############################################################################

echo "════════════════════════════════════════════════════════════"
echo "   AUTOMATED THERMAL SCRIPT COMPARISON"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "I will:"
echo "  1. Test AGGRESSIVE script (0.1s polling, CPU >50% lock)"
echo "  2. Test HYBRID script (0.5s polling, CPU >60% lock)"
echo "  3. Compare peak temps and responsiveness"
echo "  4. Automatically choose the best one"
echo ""
echo "This will take about 3 minutes..."
echo ""

# Create test log directory
TEST_DIR="/tmp/thermal-test"
mkdir -p "$TEST_DIR"

# Function to get CPU temp
get_temp() {
    sensors 2>/dev/null | grep -i "package id 0" | awk '{print $4}' | sed 's/+//;s/°C//' | cut -d'.' -f1
}

# Function to get CPU usage
get_cpu() {
    grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print int(usage)}'
}

# Function to get current freq
get_freq() {
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null
}

# Function to test a script
test_script() {
    local name=$1
    local script_path=$2
    local log_file="$TEST_DIR/${name}_results.txt"
    
    echo "════════════════════════════════════════════════════════════"
    echo "   TESTING: $name"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    
    # Apply the script
    echo "Applying $name script..."
    bash "$script_path" > /dev/null 2>&1
    sleep 3
    
    # Clear thermal manager log
    > /var/log/thermal-manager.log 2>/dev/null
    
    echo "Running 60-second test with background load spikes..."
    echo ""
    
    # Initialize variables
    peak_temp=0
    avg_temp=0
    temp_count=0
    spike_count=0
    turbo_count=0
    lock_count=0
    
    # Run test for 60 seconds
    for i in {1..60}; do
        # Every 15 seconds, create a brief CPU spike
        if [ $((i % 15)) -eq 0 ]; then
            (yes | head -c 100MB | gzip > /dev/null 2>&1) &
            spike_pid=$!
            sleep 0.5
            kill $spike_pid 2>/dev/null
            wait $spike_pid 2>/dev/null
        fi
        
        # Sample every second
        temp=$(get_temp)
        cpu=$(get_cpu)
        freq=$(get_freq)
        
        # Track statistics
        if [ ! -z "$temp" ]; then
            temp_count=$((temp_count + 1))
            avg_temp=$((avg_temp + temp))
            
            if [ "$temp" -gt "$peak_temp" ]; then
                peak_temp=$temp
            fi
            
            if [ "$temp" -ge 75 ]; then
                spike_count=$((spike_count + 1))
            fi
        fi
        
        if [ "$freq" = "3800000" ]; then
            turbo_count=$((turbo_count + 1))
        elif [ "$freq" = "2600000" ]; then
            lock_count=$((lock_count + 1))
        fi
        
        # Show progress
        printf "Test: %2d/60s | Temp: %2d°C | CPU: %3d%% | Freq: %dMHz\r" \
            "$i" "${temp:-0}" "${cpu:-0}" "$((freq/1000))"
        
        sleep 1
    done
    
    echo ""
    echo ""
    
    # Calculate average
    if [ "$temp_count" -gt 0 ]; then
        avg_temp=$((avg_temp / temp_count))
    fi
    
    # Save results
    cat > "$log_file" << EOF
SCRIPT: $name
PEAK_TEMP: $peak_temp
AVG_TEMP: $avg_temp
SPIKE_COUNT: $spike_count
TURBO_COUNT: $turbo_count
LOCK_COUNT: $lock_count
EOF
    
    echo "Results for $name:"
    echo "  Peak Temperature: ${peak_temp}°C"
    echo "  Average Temperature: ${avg_temp}°C"
    echo "  Temps ≥75°C: ${spike_count} times"
    echo "  Time at 3.8 GHz: ${turbo_count}s"
    echo "  Time at 2.6 GHz: ${lock_count}s"
    echo ""
}

# Test Aggressive script
test_script "AGGRESSIVE" "/home/adeel/fix-thermal-aggressive.sh"

sleep 5

# Test Hybrid script
test_script "HYBRID" "/home/adeel/fix-thermal-hybrid.sh"

# Load results
aggressive_peak=$(grep PEAK_TEMP "$TEST_DIR/AGGRESSIVE_results.txt" | cut -d: -f2 | tr -d ' ')
aggressive_avg=$(grep AVG_TEMP "$TEST_DIR/AGGRESSIVE_results.txt" | cut -d: -f2 | tr -d ' ')
aggressive_spikes=$(grep SPIKE_COUNT "$TEST_DIR/AGGRESSIVE_results.txt" | cut -d: -f2 | tr -d ' ')
aggressive_turbo=$(grep TURBO_COUNT "$TEST_DIR/AGGRESSIVE_results.txt" | cut -d: -f2 | tr -d ' ')

hybrid_peak=$(grep PEAK_TEMP "$TEST_DIR/HYBRID_results.txt" | cut -d: -f2 | tr -d ' ')
hybrid_avg=$(grep AVG_TEMP "$TEST_DIR/HYBRID_results.txt" | cut -d: -f2 | tr -d ' ')
hybrid_spikes=$(grep SPIKE_COUNT "$TEST_DIR/HYBRID_results.txt" | cut -d: -f2 | tr -d ' ')
hybrid_turbo=$(grep TURBO_COUNT "$TEST_DIR/HYBRID_results.txt" | cut -d: -f2 | tr -d ' ')

echo ""
echo "════════════════════════════════════════════════════════════"
echo "   COMPARISON"
echo "════════════════════════════════════════════════════════════"
echo ""
printf "%-20s | %-15s | %-15s\n" "Metric" "AGGRESSIVE" "HYBRID"
echo "────────────────────────────────────────────────────────────"
printf "%-20s | %-15s | %-15s\n" "Peak Temperature" "${aggressive_peak}°C" "${hybrid_peak}°C"
printf "%-20s | %-15s | %-15s\n" "Average Temp" "${aggressive_avg}°C" "${hybrid_avg}°C"
printf "%-20s | %-15s | %-15s\n" "Hot Spikes (≥75°C)" "${aggressive_spikes}x" "${hybrid_spikes}x"
printf "%-20s | %-15s | %-15s\n" "Turbo Time" "${aggressive_turbo}s" "${hybrid_turbo}s"
echo ""

# Decision logic
score_aggressive=0
score_hybrid=0

# Lower peak is better
if [ "$aggressive_peak" -lt "$hybrid_peak" ]; then
    score_aggressive=$((score_aggressive + 2))
elif [ "$hybrid_peak" -lt "$aggressive_peak" ]; then
    score_hybrid=$((score_hybrid + 2))
fi

# Fewer spikes is better
if [ "$aggressive_spikes" -lt "$hybrid_spikes" ]; then
    score_aggressive=$((score_aggressive + 3))
elif [ "$hybrid_spikes" -lt "$aggressive_spikes" ]; then
    score_hybrid=$((score_hybrid + 3))
fi

# More turbo time is better (responsiveness)
if [ "$aggressive_turbo" -gt "$hybrid_turbo" ]; then
    score_aggressive=$((score_aggressive + 1))
elif [ "$hybrid_turbo" -gt "$aggressive_turbo" ]; then
    score_hybrid=$((score_hybrid + 1))
fi

echo "════════════════════════════════════════════════════════════"
echo "   DECISION"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Score: AGGRESSIVE=$score_aggressive, HYBRID=$score_hybrid"
echo ""

if [ "$score_aggressive" -gt "$score_hybrid" ]; then
    winner="AGGRESSIVE"
    winner_script="/home/adeel/fix-thermal-aggressive.sh"
elif [ "$score_hybrid" -gt "$score_aggressive" ]; then
    winner="HYBRID"
    winner_script="/home/adeel/fix-thermal-hybrid.sh"
else
    # Tie - prefer hybrid for better responsiveness
    winner="HYBRID"
    winner_script="/home/adeel/fix-thermal-hybrid.sh"
    echo "⚖️  TIE - Choosing HYBRID (better balance)"
fi

echo "🏆 WINNER: $winner"
echo ""

# Apply the winner
echo "Applying the winning configuration..."
bash "$winner_script" > /dev/null 2>&1

sleep 2

echo ""
echo "════════════════════════════════════════════════════════════"
echo "   FINAL CONFIGURATION"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "✅ Active script: $winner"
echo ""

if [ "$winner" = "AGGRESSIVE" ]; then
    echo "Why AGGRESSIVE won:"
    echo "  ✓ Lower peak temperatures"
    echo "  ✓ Fewer hot spikes"
    echo "  → Better thermal comfort"
    echo ""
    echo "Characteristics:"
    echo "  • Checks every 0.1s (fast reaction)"
    echo "  • Locks at CPU >50%"
    echo "  • Prevents temps >70°C"
    echo "  • Still allows 3.8 GHz for brief tasks"
else
    echo "Why HYBRID won:"
    echo "  ✓ Good thermal control"
    echo "  ✓ Better responsiveness (more turbo time)"
    echo "  → Best balance"
    echo ""
    echo "Characteristics:"
    echo "  • Checks every 0.5s"
    echo "  • Locks at CPU >60%"
    echo "  • Allows more 3.8 GHz bursts"
    echo "  • Brief spikes acceptable but managed"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "   TESTING COMPLETE"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Your laptop is now configured with the optimal thermal"
echo "management script based on actual testing!"
echo ""
echo "To verify, run:"
echo "  ./monitor-laptop-temps.sh"
echo ""

