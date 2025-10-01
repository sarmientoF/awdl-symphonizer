# AWDL Channel Optimization Guide

## Overview

Apple Wireless Direct Link (AWDL) is the peer-to-peer protocol that powers AirDrop, Sidecar, Handoff, and other continuity features on macOS. AWDL can cause stuttering and ping spikes in gaming/streaming when it operates on a different channel than your WiFi connection.

## The Problem

When your WiFi and AWDL are on **different channels**, your Mac's radio has to rapidly switch between channels, causing:
- **Ping spikes** (100-500ms+ latency jumps)
- **Stuttering** in games and video streams
- **Packet loss**
- **Reduced throughput**

## The Solution

**Match your WiFi router's channel to AWDL's operating channel**, or ensure AWDL synchronizes to your WiFi channel.

---

## Current Status (from wdutil info)

```
WiFi:  5GHz, Channel 149/80
AWDL:  Channel 149++ (synchronized)
Status: ✓ OPTIMAL - No interference
```

Your current setup is **already optimal** because both WiFi and AWDL are on channel 149!

---

## Detection Tools

I've created two scripts to help you monitor AWDL:

### 1. Quick Check: `check_awdl_channel.sh`

```bash
~/check_awdl_channel.sh
```

**Purpose:** One-time snapshot of current WiFi and AWDL channels with analysis.

**Output:**
- Current WiFi band and channel
- Current AWDL channel sequence
- Interference analysis
- Recommendations

### 2. Live Monitor: `monitor_awdl_live.sh`

```bash
~/monitor_awdl_live.sh [interval_seconds]
```

**Purpose:** Continuous monitoring with auto-refresh (default: every 5 seconds).

**Features:**
- Real-time channel tracking
- Interference alerts
- Band-specific recommendations
- Signal strength (RSSI)

**Usage Examples:**
```bash
# Monitor with default 5-second refresh
~/monitor_awdl_live.sh

# Monitor with 10-second refresh
~/monitor_awdl_live.sh 10
```

Press `Ctrl+C` to stop monitoring.

---

## Understanding AWDL Behavior

### 5 GHz Band
- **Preferred Channel:** **149**
- **Why:** Channel 149 is in the UNII-3 band (5725-5850 MHz)
- **Advantage:** No DFS (Dynamic Frequency Selection) restrictions
- **Recommendation:** Set router to channel 149 for gaming/streaming

### 6 GHz Band (WiFi 6E)
- **AWDL Channels:** Variable, commonly uses 5, 21, 37, 53, 69, 85, 101, 117, 133, etc.
- **Detection Required:** Use monitoring scripts to see which channel AWDL selects
- **Advantage:** Minimal interference (new, uncrowded spectrum)
- **Recommendation:** Monitor AWDL's chosen channel, then match router to it

### Channel Sequence Notation
```
149++ 149++ 149++ ...
```
- **149:** The channel number
- **++:** Extended Availability Window (AWDL is staying on this channel longer)
- **All same number:** AWDL is synchronized and not hopping

If you see multiple different channels:
```
44 149 44 149 ...
```
This means AWDL is **frequency hopping**, which indicates it hasn't synchronized with your WiFi and **will cause interference**.

---

## Optimization Strategy

### Current Setup (5 GHz)
✅ **You're already optimized!**
- WiFi: Channel 149
- AWDL: Channel 149
- Result: No interference

### If You Upgrade to WiFi 6E (6 GHz)

1. **Connect to 6 GHz network**
2. **Run monitoring script:**
   ```bash
   ~/check_awdl_channel.sh
   ```
3. **Check AWDL's chosen channel** (e.g., channel 37)
4. **Log into router and set 6 GHz to match** (e.g., set to channel 37)
5. **Verify synchronization** with monitoring script

### Example 6 GHz Optimization Workflow

```bash
# Step 1: Connect Mac to 6 GHz WiFi
# (via System Settings > Wi-Fi)

# Step 2: Check what channel AWDL picks
~/check_awdl_channel.sh

# Output might show:
# WiFi:  6GHz, Channel 37
# AWDL:  Channel 37
# Status: ✓ OPTIMAL

# If they DON'T match:
# WiFi:  6GHz, Channel 53
# AWDL:  Channel 37
# Status: ⚠ INTERFERENCE

# Step 3: Change router to channel 37 (match AWDL)

# Step 4: Reconnect and verify
~/check_awdl_channel.sh
```

---

## Router Configuration

### Accessing Router Settings
1. Open browser
2. Navigate to router admin (usually `192.168.1.1` or `192.168.0.1`)
3. Login with admin credentials
4. Find WiFi/Wireless settings
5. Look for "Channel" or "Frequency" settings

### Recommended Settings

#### For 5 GHz:
- **Channel:** 149
- **Width:** 80 MHz (or 160 MHz if supported)
- **Mode:** 802.11ax (WiFi 6) or 802.11ac (WiFi 5)

#### For 6 GHz (WiFi 6E):
- **Channel:** Match AWDL (use script to detect)
- **Width:** 160 MHz (6 GHz supports wider channels)
- **Mode:** 802.11ax (WiFi 6E)

---

## Common AWDL Channels by Band

| Band    | Common AWDL Channels                     | Notes                              |
|---------|------------------------------------------|------------------------------------|
| 2.4 GHz | 1, 6, 11                                 | Not recommended (high interference)|
| 5 GHz   | **149** (primary), 36, 40, 44, 48       | 149 is most stable                 |
| 6 GHz   | 5, 21, 37, 53, 69, 85, 101, 117, 133    | Variable, use detection script     |

---

## Manual AWDL Control (Advanced)

### Disable AWDL Temporarily
```bash
sudo ifconfig awdl0 down
```

### Enable AWDL
```bash
sudo ifconfig awdl0 up
```

### Check AWDL Status
```bash
ifconfig awdl0 | grep "status"
```

**Note:** You've already configured passwordless sudo for these commands via `/etc/sudoers.d/ifconfig-awdl0`.

---

## Troubleshooting

### Problem: AWDL keeps hopping between channels

**Possible Causes:**
1. WiFi and AWDL are on incompatible channels
2. Multiple Apple devices nearby causing conflicts
3. DFS radar detection (on 5 GHz DFS channels)

**Solutions:**
- Switch router to channel 149 (5 GHz) - non-DFS
- Switch to 6 GHz if available
- Temporarily disable AWDL during critical gaming sessions

### Problem: Can't detect AWDL channel

**Solution:**
Ensure `wdutil` has proper permissions:
```bash
sudo wdutil info
```

### Problem: Still experiencing lag on matched channels

**Possible Issues:**
1. Other Apple devices nearby on different channels
2. Router using DFS channels (52-144) which may switch
3. High WiFi congestion from neighbors
4. ISP/network issues unrelated to AWDL

**Solutions:**
- Use WiFi analyzer to check for congestion
- Test with AWDL disabled: `sudo ifconfig awdl0 down`
- Check if issue persists on wired connection

---

## Advanced: Continuous Background Monitoring

To set up automated monitoring with alerts:

```bash
# Run in background with logging
nohup ~/monitor_awdl_live.sh 30 > ~/awdl_monitor.log 2>&1 &

# View log
tail -f ~/awdl_monitor.log

# Stop monitoring
pkill -f monitor_awdl_live.sh
```

---

## GEForceNowEnhanced.app Integration

If you're using GEForceNowEnhanced.app, it may automatically disable AWDL during gaming sessions. The sudo configuration in `/etc/sudoers.d/ifconfig-awdl0` allows this without password prompts.

To verify the app can control AWDL:
```bash
# Test without password
sudo -n /sbin/ifconfig awdl0 down
sudo -n /sbin/ifconfig awdl0 up
```

---

## Quick Reference Commands

```bash
# Check current status
sudo wdutil info

# Quick AWDL channel check
~/check_awdl_channel.sh

# Live monitoring
~/monitor_awdl_live.sh

# Disable AWDL
sudo ifconfig awdl0 down

# Enable AWDL
sudo ifconfig awdl0 up

# View WiFi details
system_profiler SPAirPortDataType

# Check AWDL interface status
ifconfig awdl0
```

---

## Resources

- **Manual Pages:** `man wdutil`, `man ifconfig`
- **Apple Wireless Direct Link:** AWDL is proprietary but well-documented in research papers
- **WiFi 6E Channels:** [FCC 6 GHz allocation](https://www.fcc.gov/6-ghz)

---

## Summary

1. ✅ **Current Status:** Already optimized (both on channel 149)
2. 🎯 **For 5 GHz:** Use channel 149
3. 🔍 **For 6 GHz:** Use detection scripts to find and match AWDL's channel
4. 📊 **Monitoring:** Use `check_awdl_channel.sh` or `monitor_awdl_live.sh`
5. ⚡ **Quick Fix:** Temporarily disable AWDL if needed

**Your question answered:** Yes, when you switch to 6 GHz, AWDL will use a channel within the 6 GHz band. Use the monitoring scripts to detect which one, then configure your router to match it. The process is exactly the same as what you did with 5 GHz channel 149!
