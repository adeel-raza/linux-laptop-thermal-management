# 🔥 Linux Laptop Thermal Management for Dell Laptops

> **Fix CPU overheating and hot laptop bottom on Linux | Simple one-command installation**

[![Linux](https://img.shields.io/badge/OS-Linux-orange.svg)](https://www.linux.org/)
[![Dell](https://img.shields.io/badge/Hardware-Dell%20Laptops-blue.svg)](https://www.dell.com/)

## 🎯 The Problem

On Linux, Dell laptops often experience:
- ❌ **CPU temps reaching 80-95°C** during normal use
- ❌ **Laptop bottom uncomfortably hot**
- ❌ **Fans not responding properly**
- ❌ **Brief temperature spikes** that make the laptop uncomfortable

## ✅ The Solution: Option D (Recommended)

After extensive testing, **Option D** provides the optimal balance:

| Metric | Before (No Management) | After (Option D) |
|--------|------------------------|------------------|
| Max Temperature | **79-95°C** 🔥 | **73-77°C** ✅ |
| Sustained Load | 75-85°C | **59-67°C** ✅ |
| Idle Temperature | 50-60°C | **48-55°C** ✅ |
| Max CPU Frequency | 3.8 GHz | **3.5 GHz** ⚡ |
| Comfort | Uncomfortable | **Comfortable** ✅ |

### What is Option D?

**Conservative Turbo Configuration:**
- 🎯 **CPU capped at 3.5 GHz** (300 MHz lower than max)
- 🌡️ **Thermal threshold: 72°C** (locks CPU at 2.6 GHz above this)
- 🔋 **Powersave governor** (battery efficient)
- ⚡ **Still very fast** (only 8% slower than max, imperceptible in daily use)
- ❄️ **Much cooler** (6-10°C lower than unmanaged)

---

## 🚀 Quick Installation (One Command)

### Step 1: Clone the Repository

```bash
cd ~
git clone https://github.com/adeeladnan/linux-laptop-thermal-management.git
cd linux-laptop-thermal-management
```

### Step 2: Install Option D

```bash
sudo bash install-option-d.sh
```

**That's it!** The configuration will:
- ✅ Set CPU max to 3.5 GHz
- ✅ Enable intelligent thermal management
- ✅ Set powersave governor
- ✅ Persist after reboot automatically

---

## 📊 Real-World Monitoring Sample

Here's what you'll experience with Option D during normal work:

```
Time    | Temp  | Fan    | CPU  | Freq   | Activity   | Thermal Status
────────────────────────────────────────────────────────────────────────────
03:00:01 |  52°C |      0 |  10% | 0.90GHz | LIGHT      | ✓ COMFORTABLE
03:00:26 |  53°C |      0 |   8% | 3.50GHz | IDLE       | ✓ COMFORTABLE
03:00:42 |  70°C |      0 |  32% | 3.50GHz | MODERATE   | ○ WARM
03:01:03 |  61°C |   2985 |  16% | 3.50GHz | LIGHT      | ✓ COMFORTABLE
03:01:28 |  53°C |   3062 |  19% | 3.50GHz | LIGHT      | ✓ COMFORTABLE
03:02:00 |  68°C |   3291 |  75% | 3.50GHz | MAX LOAD   | ○ WARM
03:02:02 |  59°C |   3217 |  64% | 2.59GHz | HEAVY      | ✓ COMFORTABLE (locked)
03:02:48 |  48°C |   3278 |   7% | 3.50GHz | IDLE       | ❄️ COOL
03:03:06 |  64°C |      0 |  92% | 3.50GHz | MAX LOAD   | ○ WARM
03:03:33 |  59°C |      0 |  92% | 2.60GHz | MAX LOAD   | ✓ COMFORTABLE (locked)
```

**Key Observations:**
- Most time spent: **48-60°C** (cool to comfortable)
- Under heavy load: **59-67°C** (comfortable, fans active)
- Brief spikes: **70-77°C max** (acceptable, quick recovery)
- No more 80°C+ uncomfortable heat!

---

## 🔧 How It Works

### Intelligent Thermal Management

The system uses a **hybrid predictive + reactive approach**:

1. **Predictive Lock** (prevents spikes):
   - When CPU > 70% AND temp > 62°C → Lock to 2.6 GHz
   
2. **Emergency Lock** (catches missed spikes):
   - When temp > 72°C → Immediately lock to 2.6 GHz

3. **Unlock** (restore performance):
   - When CPU < 35% AND temp < 58°C → Unlock to 3.5 GHz

This creates a smooth experience:
- ✅ Turbo boost available when needed
- ✅ Proactive thermal management prevents spikes
- ✅ Quick cooldown and recovery
- ✅ Comfortable laptop temperature

---

## 📱 Monitoring Your System

To see real-time thermal performance:

```bash
~/monitor-laptop-temps.sh
```

Press `Ctrl+C` to stop and see a summary report.

---

## 🔄 After Reboot

Everything persists automatically! The installation creates two systemd services:

1. `thermal-manager.service` - Manages CPU frequency based on temperature
2. `set-governor.service` - Sets powersave governor on boot

Check status anytime:
```bash
systemctl status thermal-manager.service
systemctl status set-governor.service
```

---

## ⚙️ Other Configurations (Advanced)

If you want to experiment with different trade-offs:

### Option A: Maximum Cooling (Coolest, Slower)
```bash
PREDICT_CPU_THRESHOLD=60
PREDICT_TEMP_THRESHOLD=62
EMERGENCY_TEMP=68
MAX_BURST_FREQ="2600000"  # 2.6 GHz max
```
**Result:** 62-65°C max, no turbo bursts, slowest

### Option B: Full Turbo Balanced
```bash
PREDICT_CPU_THRESHOLD=70
PREDICT_TEMP_THRESHOLD=65
EMERGENCY_TEMP=70
MAX_BURST_FREQ="3800000"  # 3.8 GHz max
```
**Result:** 79-83°C max, full performance, warmer

### Option C: Relaxed (Full Speed, Less Aggressive)
```bash
PREDICT_CPU_THRESHOLD=75
PREDICT_TEMP_THRESHOLD=67
EMERGENCY_TEMP=75
MAX_BURST_FREQ="3800000"  # 3.8 GHz max
```
**Result:** 75-85°C max, full 3.8 GHz, occasional warm spikes

### Option D: Conservative Turbo ⭐ **RECOMMENDED**
```bash
PREDICT_CPU_THRESHOLD=70
PREDICT_TEMP_THRESHOLD=62
EMERGENCY_TEMP=72
MAX_BURST_FREQ="3500000"  # 3.5 GHz max
```
**Result:** 73-77°C max, 3.5 GHz, best balance ✅

To modify, edit `/usr/local/bin/thermal-manager.sh` and restart:
```bash
sudo systemctl restart thermal-manager.service
```

---

## 🐛 Troubleshooting

### Check if services are running:
```bash
systemctl status thermal-manager.service
systemctl status set-governor.service
```

### Check current configuration:
```bash
echo "Max Freq: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq | awk '{printf "%.1f GHz", $1/1000000}')"
echo "Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
```

### View thermal manager logs:
```bash
sudo tail -50 /var/log/thermal-manager.log
```

### Reinstall if something breaks:
```bash
cd ~/linux-laptop-thermal-management
sudo bash install-option-d.sh
```

---

## 📈 Why Option D is Recommended

After testing all configurations for over 4 hours with real workloads:

| Factor | Option D Rating |
|--------|----------------|
| Thermal Comfort | ⭐⭐⭐⭐⭐ (77°C max) |
| Performance | ⭐⭐⭐⭐⭐ (3.5 GHz, imperceptible difference) |
| Battery Life | ⭐⭐⭐⭐⭐ (powersave governor) |
| Sustained Load | ⭐⭐⭐⭐⭐ (59-67°C under load!) |
| Stability | ⭐⭐⭐⭐⭐ (no throttling, smooth) |

**The 300 MHz reduction (3.8 → 3.5 GHz) is only 8% slower, but results in 6-10°C cooler temperatures. You won't notice the speed difference, but you WILL notice the comfort difference!**

---

## 🤝 Contributing

If you find this useful or have improvements, feel free to:
- ⭐ Star this repository
- 🐛 Report issues
- 🔧 Submit pull requests
- 💬 Share your thermal results

---

## 📄 License

MIT License - Feel free to use and modify!

---

## 🙏 Credits

Developed by [Adeel Adnan](https://github.com/adeeladnan) for Dell Precision laptops on Linux.

If this saved your laptop from overheating, consider starring the repo! ⭐
