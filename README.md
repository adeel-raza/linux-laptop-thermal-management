# Linux Laptop Thermal Management System

A comprehensive thermal management solution for Linux laptops that provides Windows-like thermal behavior with configurable temperature thresholds and CPU frequency control.

## 🚀 Features

- **Windows-like Thermal Behavior**: Mimics Windows thermal management patterns
- **Configurable Thresholds**: Multiple temperature and performance profiles
- **Real-time Monitoring**: Live temperature and frequency monitoring
- **CPU Governor Integration**: Works with Intel P-State and other governors
- **Systemd Service**: Automatic startup and management
- **Multiple Configurations**: Stricter, Balanced, and Performance modes

## 📁 Project Structure

```
thermal-management-project/
├── thermal-manager.sh           # Main thermal management script
├── thermal-manager.sh.backup    # Original backup configuration
├── monitor-laptop-temps.sh      # Real-time monitoring script
└── README.md                    # This file
```

## ⚙️ Current Configuration

### Active Settings (Stricter Mode)
- **Predict Threshold**: 58°C (locks CPU if temp ≥58°C)
- **Emergency Temp**: 68°C (force lock at 68°C)
- **Unlock Threshold**: 58°C (unlocks when temp <58°C)
- **Max Burst Frequency**: 3.5 GHz
- **CPU Governor**: powersave
- **Energy Preference**: balance_performance

### Performance Profile
- **Light Tasks**: 3.5 GHz bursts (excellent)
- **Sustained Load**: ~2.0 GHz (normal laptop behavior)
- **Thermal Safety**: Very conservative (laptop stays cool)
- **Battery Life**: Good

## 🔧 Installation

1. **Copy scripts to system directories:**
   ```bash
   sudo cp thermal-manager.sh /usr/local/bin/
   sudo cp monitor-laptop-temps.sh /usr/local/bin/
   sudo chmod +x /usr/local/bin/thermal-manager.sh
   sudo chmod +x /usr/local/bin/monitor-laptop-temps.sh
   ```

2. **Create systemd service:**
   ```bash
   sudo cp thermal-manager.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable thermal-manager
   sudo systemctl start thermal-manager
   ```

3. **Monitor system:**
   ```bash
   ~/monitor-laptop-temps.sh
   ```

## 📊 Configuration Options

### Stricter Mode (Current)
- **Use Case**: Cool laptop, moderate performance
- **Temps**: 58-68°C
- **Performance**: 2.0 GHz sustained, 3.5 GHz bursts
- **Best For**: General use, battery life

### Balanced Mode
- **Use Case**: Better sustained performance
- **Temps**: 62-72°C
- **Performance**: 2.6 GHz sustained, 3.5 GHz bursts
- **Best For**: Heavy workloads, development

### Performance Mode
- **Use Case**: Maximum performance
- **Temps**: 70-80°C
- **Performance**: 3.5 GHz sustained
- **Best For**: Gaming, intensive tasks

## 🔍 Monitoring

The system provides real-time monitoring with:
- Current CPU temperature
- Fan speed (if available)
- CPU usage percentage
- Current frequency
- Activity level (IDLE/LIGHT/MODERATE/HEAVY/MAX LOAD)
- Thermal status indicators

## 🛠️ Troubleshooting

### CPU Stuck at Low Frequencies
- Check if thermal manager is running: `systemctl status thermal-manager`
- Verify CPU governor: `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`
- Check energy preference: `cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference`

### High Temperatures
- Verify thermal thresholds in script
- Check if fans are working
- Consider switching to stricter configuration

### Service Not Starting
- Check logs: `journalctl -u thermal-manager`
- Verify script permissions
- Check systemd service file

## 📝 Recent Changes

### October 27, 2024
- **Configuration Analysis**: Identified current stricter 58°C/68°C configuration
- **Performance Testing**: Confirmed 2.0 GHz sustained performance under load
- **Governor Investigation**: Discovered powersave governor is primary limiter
- **Documentation**: Created comprehensive README and project structure

### October 25, 2024
- **Script Updates**: Modified thermal thresholds from 65°C to 68°C emergency temp
- **Backup Created**: Preserved original configuration
- **Service Optimization**: Improved systemd integration

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## ⚠️ Disclaimer

This thermal management system modifies CPU frequency limits and system behavior. Use at your own risk. Always monitor system temperatures and performance when making changes.

## 📞 Support

For issues or questions:
1. Check the troubleshooting section
2. Review system logs
3. Create an issue in the repository
4. Monitor system behavior with the provided tools

---

**Current Status**: System running in Stricter mode with passive monitoring. CPU performance limited by powersave governor (normal laptop behavior).
