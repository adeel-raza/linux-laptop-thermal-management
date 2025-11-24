# Linux Laptop Thermal Management System

A comprehensive dual-mode thermal management solution for Linux laptops that provides intelligent CPU frequency control with configurable NORMAL and PERFORMANCE modes. This system mimics Windows-like thermal behavior while offering flexibility for different use cases.

## 🚀 Features

- **Dual-Mode Operation**: Switch between NORMAL and PERFORMANCE modes on the fly
- **Intelligent Thermal Management**: Predictive locking based on CPU usage and temperature
- **Fast Response**: 0.1s polling interval (10 checks per second) for rapid thermal response
- **Configurable Thresholds**: Separate temperature and CPU thresholds for each mode
- **CPU Governor Integration**: Automatic governor selection based on mode
- **Intel P-State Support**: Optimized settings for Intel processors
- **Systemd Service**: Automatic startup and management
- **Comprehensive Logging**: Detailed activity logs in `/var/log/thermal-manager.log`

## 📁 Project Structure

```
thermal-management-project/
├── thermal-manager.sh           # Main dual-mode thermal management script
├── thermal-manager.sh.backup    # Original backup configuration
├── thermal-manager.service      # Systemd service file
├── monitor-laptop-temps.sh      # Real-time monitoring script (optional)
└── README.md                    # This file
```

## 🎯 Dual-Mode System

### NORMAL Mode (Default)
**Best for**: General use, battery life, balanced performance

- **Max Burst Frequency**: 3.7 GHz (single-core turbo)
- **Max Sustained Frequency**: 2.6 GHz (when locked)
- **Lock Thresholds**: 
  - CPU >75% AND temp >62°C (predictive)
  - CPU >85% AND temp >65°C (high CPU)
- **Emergency Lock**: 72°C
- **Unlock Thresholds**: CPU <40% AND temp <60°C
- **CPU Governor**: schedutil or powersave
- **Energy Preference**: balance_power

**Performance Profile**:
- Light tasks: 3.7 GHz bursts
- Sustained load: ~2.6 GHz
- Thermal safety: Conservative (stays cool)
- Battery life: Excellent

### PERFORMANCE Mode
**Best for**: Gaming, intensive workloads, maximum performance

- **Max Burst Frequency**: 4.2 GHz (single-core turbo)
- **Max Sustained Frequency**: 3.8 GHz (when locked, near max all-core)
- **Lock Thresholds**:
  - CPU >99% AND temp >87°C (virtually never triggers)
  - CPU >99% AND temp >87°C (high CPU)
- **Emergency Lock**: 88°C (protects from 90°C+ spikes)
- **Unlock Thresholds**: CPU <80% AND temp <82°C
- **CPU Governor**: performance or schedutil
- **Energy Preference**: performance
- **Intel P-State**: min_perf_pct set to 80% (prevents 1.7-1.9 GHz cap)

**Performance Profile**:
- Light tasks: 4.2 GHz single-core, ~3.8 GHz all-core
- Sustained load: ~3.8 GHz
- Thermal safety: Minimal throttling (allows higher temps)
- Battery life: Reduced (performance priority)

## 🔧 Installation

### 1. Copy Scripts to System Directories

```bash
sudo cp thermal-manager.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/thermal-manager.sh
```

### 2. Set Initial Mode (Optional)

By default, the system starts in NORMAL mode. To start in PERFORMANCE mode:

```bash
echo "PERFORMANCE" | sudo tee /etc/thermal-manager-mode
```

Or to explicitly set NORMAL mode:

```bash
echo "NORMAL" | sudo tee /etc/thermal-manager-mode
```

### 3. Create Systemd Service

```bash
sudo cp thermal-manager.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable thermal-manager
sudo systemctl start thermal-manager
```

### 4. Verify Installation

```bash
# Check service status
sudo systemctl status thermal-manager

# View logs
sudo tail -f /var/log/thermal-manager.log

# Check current mode
cat /etc/thermal-manager-mode
```

## 🔄 Switching Between Modes

### Method 1: Change Mode File (Requires Service Restart)

```bash
# Switch to PERFORMANCE mode
echo "PERFORMANCE" | sudo tee /etc/thermal-manager-mode
sudo systemctl restart thermal-manager

# Switch to NORMAL mode
echo "NORMAL" | sudo tee /etc/thermal-manager-mode
sudo systemctl restart thermal-manager
```

### Method 2: Create a Mode Switch Script (Recommended)

Create a helper script for easy mode switching:

```bash
#!/bin/bash
# Save as: /usr/local/bin/thermal-mode

if [ "$1" = "performance" ] || [ "$1" = "perf" ]; then
    echo "PERFORMANCE" | sudo tee /etc/thermal-manager-mode > /dev/null
    sudo systemctl restart thermal-manager
    echo "Switched to PERFORMANCE mode"
elif [ "$1" = "normal" ]; then
    echo "NORMAL" | sudo tee /etc/thermal-manager-mode > /dev/null
    sudo systemctl restart thermal-manager
    echo "Switched to NORMAL mode"
else
    current=$(cat /etc/thermal-manager-mode 2>/dev/null || echo "NORMAL")
    echo "Current mode: $current"
    echo "Usage: thermal-mode [normal|performance]"
fi
```

Make it executable:
```bash
sudo chmod +x /usr/local/bin/thermal-mode
```

Then use it:
```bash
sudo thermal-mode performance  # Switch to PERFORMANCE
sudo thermal-mode normal      # Switch to NORMAL
thermal-mode                  # Check current mode
```

## 📊 How It Works

### Locking Mechanism

The thermal manager uses a predictive locking system:

1. **Predictive Lock**: When CPU usage and temperature both exceed thresholds, the system proactively locks to prevent thermal spikes
2. **Emergency Lock**: If temperature reaches emergency threshold, frequency is immediately locked regardless of CPU usage
3. **High CPU Lock**: If CPU usage is very high with elevated temperature, frequency is locked

### Unlocking Mechanism

The system unlocks when:
- CPU usage drops below unlock threshold **AND**
- Temperature drops below unlock threshold

### Continuous Enforcement

The script continuously enforces frequency limits every 0.1 seconds to prevent race conditions and ensure thermal safety.

## 🔍 Monitoring

### View Logs

```bash
# Real-time log monitoring
sudo tail -f /var/log/thermal-manager.log

# View recent activity
sudo tail -n 50 /var/log/thermal-manager.log

# Search for specific events
sudo grep "LOCKED" /var/log/thermal-manager.log
sudo grep "UNLOCKED" /var/log/thermal-manager.log
```

### Check Current State

```bash
# Current frequency lock state
cat /tmp/thermal-manager-state

# Current CPU frequency
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq

# Current CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Current temperature
sensors | grep -i "package id 0"
```

### Optional Monitoring Script

If you have `monitor-laptop-temps.sh`, you can use it for real-time monitoring:

```bash
~/monitor-laptop-temps.sh
```

## 🛠️ Troubleshooting

### CPU Stuck at Low Frequencies

1. Check if thermal manager is running:
   ```bash
   sudo systemctl status thermal-manager
   ```

2. Check current lock state:
   ```bash
   cat /tmp/thermal-manager-state
   ```

3. Verify CPU governor:
   ```bash
   cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
   ```

4. Check energy preference (Intel):
   ```bash
   cat /sys/devices/system/cpu/intel_pstate/energy_performance_preference
   ```

5. If in PERFORMANCE mode, check min_perf_pct:
   ```bash
   cat /sys/devices/system/cpu/intel_pstate/min_perf_pct
   ```

### High Temperatures

1. Verify thermal thresholds in script match your needs
2. Check if fans are working properly
3. Consider switching to NORMAL mode if in PERFORMANCE mode
4. Check for background processes consuming CPU

### Service Not Starting

1. Check service logs:
   ```bash
   sudo journalctl -u thermal-manager -n 50
   ```

2. Verify script permissions:
   ```bash
   ls -l /usr/local/bin/thermal-manager.sh
   ```

3. Test script manually:
   ```bash
   sudo /usr/local/bin/thermal-manager.sh
   ```

4. Check systemd service file:
   ```bash
   cat /etc/systemd/system/thermal-manager.service
   ```

### Mode Not Changing

1. Verify mode file exists and has correct content:
   ```bash
   cat /etc/thermal-manager-mode
   ```

2. Restart the service after changing mode:
   ```bash
   sudo systemctl restart thermal-manager
   ```

3. Check logs to confirm mode loaded:
   ```bash
   sudo tail /var/log/thermal-manager.log | grep "MODE"
   ```

## 📝 Recent Changes

### November 24, 2024 - Dual-Mode System
- **Major Feature**: Implemented dual-mode system (NORMAL and PERFORMANCE)
- **Mode Configuration**: Added `/etc/thermal-manager-mode` file for persistent mode selection
- **NORMAL Mode**: Balanced performance with 3.7 GHz max, 2.6 GHz sustained
- **PERFORMANCE Mode**: Maximum performance with 4.2 GHz single-core, 3.8 GHz all-core
- **Governor Management**: Automatic governor selection based on mode
- **Intel P-State Optimization**: Added min_perf_pct configuration for PERFORMANCE mode to prevent aggressive throttling
- **Enhanced Logging**: Improved log messages with mode information
- **Better Thresholds**: Mode-specific temperature and CPU thresholds

### October 27, 2024
- **Configuration Analysis**: Identified current stricter 58°C/68°C configuration
- **Performance Testing**: Confirmed 2.0 GHz sustained performance under load
- **Governor Investigation**: Discovered powersave governor is primary limiter
- **Documentation**: Created comprehensive README and project structure

### October 25, 2024
- **Script Updates**: Modified thermal thresholds from 65°C to 68°C emergency temp
- **Backup Created**: Preserved original configuration
- **Service Optimization**: Improved systemd integration

## ⚙️ Configuration Details

### NORMAL Mode Thresholds

| Setting | Value | Description |
|---------|-------|-------------|
| Max Burst | 3.7 GHz | Single-core turbo frequency |
| Max Sustained | 2.6 GHz | Frequency when locked |
| Predict CPU | 75% | Lock if CPU exceeds this |
| Predict Temp | 62°C | Lock if temp exceeds this |
| Emergency | 72°C | Force lock at this temperature |
| Unlock CPU | 40% | Unlock when CPU below this |
| Unlock Temp | 60°C | Unlock when temp below this |
| High CPU | 85% | High CPU threshold |
| High CPU Temp | 65°C | High CPU temp threshold |

### PERFORMANCE Mode Thresholds

| Setting | Value | Description |
|---------|-------|-------------|
| Max Burst | 4.2 GHz | Single-core turbo frequency |
| Max Sustained | 3.8 GHz | Frequency when locked |
| Predict CPU | 99% | Lock if CPU exceeds this |
| Predict Temp | 87°C | Lock if temp exceeds this |
| Emergency | 88°C | Force lock at this temperature |
| Unlock CPU | 80% | Unlock when CPU below this |
| Unlock Temp | 82°C | Unlock when temp below this |
| High CPU | 99% | High CPU threshold |
| High CPU Temp | 87°C | High CPU temp threshold |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly on your system
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📄 License

This project is open source and available under the MIT License.

## ⚠️ Disclaimer

This thermal management system modifies CPU frequency limits and system behavior. Use at your own risk. Always monitor system temperatures and performance when making changes. The PERFORMANCE mode allows higher temperatures - ensure your laptop cooling system is adequate.

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review system logs: `sudo tail -f /var/log/thermal-manager.log`
3. Check service status: `sudo systemctl status thermal-manager`
4. Create an issue in the repository
5. Monitor system behavior with the provided tools

## 🎓 Understanding the Modes

### When to Use NORMAL Mode
- General computing tasks
- Web browsing, office work
- Battery-powered operation
- When you want cooler temperatures
- Development work (most cases)

### When to Use PERFORMANCE Mode
- Gaming
- Video encoding/rendering
- Compiling large projects
- CPU-intensive workloads
- When maximum performance is needed
- When plugged into AC power

**Note**: PERFORMANCE mode will result in higher temperatures and reduced battery life. Only use when necessary.

---

**Current Status**: System supports dual-mode operation with intelligent thermal management. Default mode is NORMAL for balanced performance and battery life.
