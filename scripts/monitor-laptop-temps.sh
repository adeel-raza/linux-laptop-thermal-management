#!/bin/bash

# Real-time Laptop Temperature & Thermal Comfort Monitor
# Monitors temps, fan speed, CPU freq, and provides thermal feedback

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Trap Ctrl+C to show summary
trap 'show_summary; exit' INT

# Get core temperature
get_temp() {
    sensors 2>/dev/null | grep -i 'Package id 0:' | awk '{print $4}' | sed 's/+//;s/°C//' | cut -d'.' -f1
}

# Get fan speed
get_fan() {
    sensors 2>/dev/null | grep -i 'fan1:' | awk '{print $2}'
}

# Get CPU usage
get_cpu() {
    top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d'.' -f1
}

# Get CPU frequency
get_freq() {
    freq_mhz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
    if [ -n "$freq_mhz" ]; then
        echo "scale=2; $freq_mhz / 1000000" | bc
    else
        echo "N/A"
    fi
}

# Get turbo status
get_turbo() {
    turbo_status=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null)
    if [ "$turbo_status" = "0" ]; then
        echo "ON"
    else
        echo "OFF"
    fi
}

# Thermal comfort assessment
assess_temp() {
    local temp=$1
    local cpu=$2
    
    if [ "$temp" -lt 50 ]; then
        echo -e "${GREEN}❄️  COOL - Excellent!${NC}"
        return 5
    elif [ "$temp" -lt 60 ]; then
        echo -e "${GREEN}✓ COMFORTABLE - Perfect${NC}"
        return 4
    elif [ "$temp" -lt 70 ]; then
        echo -e "${CYAN}○ WARM - Acceptable${NC}"
        return 3
    elif [ "$temp" -lt 80 ]; then
        echo -e "${YELLOW}⚠  GETTING HOT - Laptop bottom warming up${NC}"
        return 2
    elif [ "$temp" -lt 90 ]; then
        echo -e "${RED}⚠⚠ HOT - Laptop bottom uncomfortable${NC}"
        return 1
    else
        echo -e "${RED}✗✗ CRITICAL - Too hot!${NC}"
        return 0
    fi
}

# Activity classification
classify_activity() {
    local cpu=$1
    
    if [ "$cpu" -lt 10 ]; then
        echo "IDLE"
    elif [ "$cpu" -lt 25 ]; then
        echo "LIGHT"
    elif [ "$cpu" -lt 50 ]; then
        echo "MODERATE"
    elif [ "$cpu" -lt 75 ]; then
        echo "HEAVY"
    else
        echo "MAX LOAD"
    fi
}

# Show summary on exit
show_summary() {
    echo ""
    echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}   THERMAL COMFORT SUMMARY${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ "$total_samples" -eq 0 ]; then
        echo "No data collected."
        return
    fi
    
    # Calculate averages
    avg_temp=$((temp_sum / total_samples))
    avg_cpu=$((cpu_sum / total_samples))
    avg_fan=$((fan_sum / total_samples))
    
    # Calculate percentages
    cool_pct=$((cool_count * 100 / total_samples))
    comfortable_pct=$((comfortable_count * 100 / total_samples))
    warm_pct=$((warm_count * 100 / total_samples))
    hot_pct=$((hot_count * 100 / total_samples))
    critical_pct=$((critical_count * 100 / total_samples))
    
    # Thermal comfort percentage (cool + comfortable + warm)
    comfort_pct=$((cool_pct + comfortable_pct + warm_pct))
    
    echo -e "${CYAN}Monitoring Duration:${NC}"
    echo "  Total samples: $total_samples ($(($total_samples * 2)) seconds)"
    echo ""
    
    echo -e "${CYAN}Temperature Statistics:${NC}"
    echo "  Average temp: ${avg_temp}°C"
    echo "  Peak temp:    ${peak_temp}°C"
    echo "  Min temp:     ${min_temp}°C"
    echo "  Range:        $((peak_temp - min_temp))°C"
    echo ""
    
    echo -e "${CYAN}System Performance:${NC}"
    echo "  Average CPU:  ${avg_cpu}%"
    echo "  Average Fan:  ${avg_fan} RPM"
    echo ""
    
    echo -e "${CYAN}Thermal Comfort Breakdown:${NC}"
    echo -e "  ${GREEN}❄️  Cool (<50°C):${NC}       ${cool_pct}% ($cool_count samples)"
    echo -e "  ${GREEN}✓ Comfortable (50-60°C):${NC} ${comfortable_pct}% ($comfortable_count samples)"
    echo -e "  ${CYAN}○ Warm (60-70°C):${NC}       ${warm_pct}% ($warm_count samples)"
    echo -e "  ${YELLOW}⚠  Hot (70-90°C):${NC}        ${hot_pct}% ($hot_count samples)"
    echo -e "  ${RED}✗ Critical (>90°C):${NC}     ${critical_pct}% ($critical_count samples)"
    echo ""
    
    echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}   LAPTOP BOTTOM COMFORT VERDICT${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ "$hot_pct" -eq 0 ] && [ "$critical_pct" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✓✓✓ EXCELLENT - Laptop bottom stays comfortable!${NC}"
        echo -e "${GREEN}Your configuration (Cool mode + powersave) is working perfectly.${NC}"
        echo -e "${GREEN}The laptop bottom should never feel uncomfortably hot.${NC}"
    elif [ "$hot_pct" -lt 10 ]; then
        echo -e "${GREEN}${BOLD}✓✓ VERY GOOD - Mostly comfortable${NC}"
        echo -e "${GREEN}Laptop bottom is comfortable ${comfort_pct}% of the time.${NC}"
        echo -e "${YELLOW}Brief hot spikes (${hot_pct}%) are acceptable for turbo boost.${NC}"
    elif [ "$hot_pct" -lt 25 ]; then
        echo -e "${CYAN}${BOLD}✓ GOOD - Generally comfortable${NC}"
        echo -e "${CYAN}Laptop bottom is comfortable most of the time (${comfort_pct}%).${NC}"
        echo -e "${YELLOW}Occasional warmth (${hot_pct}%) during intensive tasks is normal.${NC}"
    elif [ "$hot_pct" -lt 50 ]; then
        echo -e "${YELLOW}${BOLD}⚠ ACCEPTABLE - Gets warm during load${NC}"
        echo -e "${YELLOW}Laptop bottom gets warm ${hot_pct}% of the time.${NC}"
        echo -e "${YELLOW}Consider: Using a laptop stand or cooling pad.${NC}"
    else
        echo -e "${RED}${BOLD}⚠⚠ NOT OPTIMAL - Too hot too often${NC}"
        echo -e "${RED}Laptop bottom is hot ${hot_pct}% of the time.${NC}"
        echo -e "${RED}Recommendations:${NC}"
        echo "  • Check thermal paste"
        echo "  • Clean vents"
        echo "  • Use cooling pad"
        echo "  • Consider switching to 'Cool-Bottom' BIOS mode"
    fi
    
    echo ""
    echo -e "${CYAN}Average temp of ${avg_temp}°C means:${NC}"
    if [ "$avg_temp" -lt 55 ]; then
        echo -e "${GREEN}  → Laptop bottom: COOL to touch ✓${NC}"
    elif [ "$avg_temp" -lt 65 ]; then
        echo -e "${GREEN}  → Laptop bottom: Slightly warm but comfortable ✓${NC}"
    elif [ "$avg_temp" -lt 75 ]; then
        echo -e "${CYAN}  → Laptop bottom: Noticeably warm○${NC}"
    else
        echo -e "${YELLOW}  → Laptop bottom: Hot to the touch ⚠${NC}"
    fi
    
    echo ""
}

# Initialize tracking variables
total_samples=0
cool_count=0
comfortable_count=0
warm_count=0
hot_count=0
critical_count=0
temp_sum=0
fan_sum=0
cpu_sum=0
peak_temp=0
min_temp=999

echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}   REAL-TIME LAPTOP THERMAL COMFORT MONITOR${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Configuration:${NC}"
echo "  BIOS Mode: Cool"
echo "  CPU Governor: powersave"
echo ""
echo -e "${YELLOW}Instructions:${NC}"
echo "  • Continue your normal work (Cursor, Chrome, etc.)"
echo "  • Watch the thermal feedback below"
echo "  • Press Ctrl+C when you want to see the summary"
echo ""
echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Time    | Temp  | Fan    | CPU  | Freq   | Activity   | Thermal Status${NC}"
echo "────────────────────────────────────────────────────────────────────────────"

# Main monitoring loop
while true; do
    temp=$(get_temp)
    fan=$(get_fan)
    cpu=$(get_cpu)
    freq=$(get_freq)
    turbo=$(get_turbo)
    
    if [ -z "$temp" ] || [ "$temp" = "" ]; then
        echo "Error: Cannot read temperature. Install lm-sensors."
        exit 1
    fi
    
    activity=$(classify_activity $cpu)
    timestamp=$(date +"%H:%M:%S")
    
    # Assess thermal comfort
    status=$(assess_temp $temp $cpu)
    status_code=$?
    
    # Track statistics
    total_samples=$((total_samples + 1))
    temp_sum=$((temp_sum + temp))
    cpu_sum=$((cpu_sum + cpu))
    
    if [ -n "$fan" ] && [ "$fan" != "" ]; then
        fan_rpm=$(echo "$fan" | grep -oE '[0-9]+')
        if [ -n "$fan_rpm" ]; then
            fan_sum=$((fan_sum + fan_rpm))
        fi
    fi
    
    # Track temperature distribution
    case $status_code in
        5) cool_count=$((cool_count + 1)) ;;
        4) comfortable_count=$((comfortable_count + 1)) ;;
        3) warm_count=$((warm_count + 1)) ;;
        2|1) hot_count=$((hot_count + 1)) ;;
        0) critical_count=$((critical_count + 1)) ;;
    esac
    
    # Track peak/min
    if [ "$temp" -gt "$peak_temp" ]; then
        peak_temp=$temp
    fi
    if [ "$temp" -lt "$min_temp" ]; then
        min_temp=$temp
    fi
    
    # Display current reading
    printf "%s | %3d°C | %6s | %3d%% | %4sGHz | %-10s | %s\n" \
        "$timestamp" "$temp" "$fan" "$cpu" "$freq" "$activity" "$status"
    
    sleep 2
done

