#!/bin/zsh
#
# Live AWDL Channel Monitor with Continuous Monitoring
# Monitors AWDL channel changes and alerts when interference is detected
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default interval (seconds)
INTERVAL=${1:-5}
CONTINUOUS=true

# Track if we've already notified about current mismatch
LAST_NOTIFIED_STATE=""

# Trap Ctrl+C
trap 'echo "\n${YELLOW}Monitoring stopped.${NC}"; exit 0' INT

show_notification() {
    local MESSAGE="$1"
    
    # Use osascript to show a native macOS notification with action button
    osascript <<EOF >/dev/null 2>&1 &
tell application "System Events"
    display notification "$MESSAGE" with title "⚠️ AWDL Channel Mismatch Detected" subtitle "WiFi: Ch ${WIFI_CHAN_NUM} | AWDL: Ch ${AWDL_CHAN_NUM}" sound name "Ping"
end tell
EOF

    # Also show a more prominent dialog for critical alerts
    osascript <<EOF >/dev/null 2>&1 &
tell application "System Events"
    activate
    display dialog "⚠️ AWDL CHANNEL MISMATCH DETECTED\n\nYour WiFi and AWDL are on different channels, which causes lag spikes and stuttering in games/streaming.\n\nCurrent Status:\n• WiFi Channel: ${WIFI_CHAN_NUM} (${WIFI_BAND} GHz)\n• AWDL Channel: ${AWDL_CHAN_NUM}\n\nAction Required:\n$MESSAGE\n\nRouter Settings:\n1. Open your router admin page\n2. Navigate to WiFi settings\n3. Change ${WIFI_BAND} GHz channel to ${AWDL_CHAN_NUM}\n4. Save and reconnect" buttons {"Dismiss", "Open Router (192.168.1.1)"} default button "Open Router (192.168.1.1)" with title "AWDL Channel Monitor" with icon caution giving up after 60
    
    if button returned of result is "Open Router (192.168.1.1)" then
        open location "http://192.168.1.1"
    end if
end tell
EOF
}

show_header() {
    clear
    echo "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo "${BOLD}${BLUE}    Live AWDL & WiFi Channel Monitor (Updates every ${INTERVAL}s)${NC}"
    echo "${BOLD}${BLUE}    Press Ctrl+C to stop${NC}"
    echo "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo
}

get_channel_info() {
    # Get AWDL and WiFi info
    local WDUTIL_OUTPUT=$(sudo wdutil info 2>/dev/null)
    
    # Extract WiFi channel (format: 5g149/80 or 6g37/160)
    WIFI_CHANNEL=$(echo "$WDUTIL_OUTPUT" | grep "^    Channel " | awk '{print $3}')
    WIFI_BAND=$(echo "$WIFI_CHANNEL" | sed -n 's/\([0-9]\)g.*/\1/p')
    WIFI_CHAN_NUM=$(echo "$WIFI_CHANNEL" | sed -n 's/.*g\([0-9]*\).*/\1/p')
    WIFI_WIDTH=$(echo "$WIFI_CHANNEL" | sed -n 's/.*\/\([0-9]*\)/\1/p')
    
    # Extract AWDL channel sequence
    AWDL_SEQUENCE=$(echo "$WDUTIL_OUTPUT" | grep "^    Channel Sequence" | sed 's/.*: //')
    AWDL_CHANNEL=$(echo "$AWDL_SEQUENCE" | awk '{print $1}' | sed 's/++//g')
    AWDL_CHAN_NUM=$AWDL_CHANNEL
    
    # Determine if there are multiple channels in sequence
    AWDL_UNIQUE_CHANNELS=$(echo "$AWDL_SEQUENCE" | tr ' ' '\n' | sed 's/++//g' | sort -u | tr '\n' ' ')
    AWDL_CHANNEL_COUNT=$(echo "$AWDL_UNIQUE_CHANNELS" | wc -w | tr -d ' ')
    
    # Extract RSSI
    WIFI_RSSI=$(echo "$WDUTIL_OUTPUT" | grep "^    RSSI " | awk '{print $3, $4}')
    
    # Extract SSID
    WIFI_SSID=$(echo "$WDUTIL_OUTPUT" | grep "^    SSID " | sed 's/.*: //')
}

display_status() {
    show_header
    
    # Timestamp
    echo "${CYAN}Last Updated: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo
    
    # WiFi Info
    echo "${GREEN}${BOLD}WiFi Interface (en0):${NC}"
    echo "  ${BOLD}SSID:${NC}     ${WIFI_SSID}"
    echo "  ${BOLD}Band:${NC}     ${WIFI_BAND}.4 GHz" # Showing as X.4 GHz (e.g., 5.4 GHz, 6.4 GHz)
    echo "  ${BOLD}Channel:${NC}  ${WIFI_CHAN_NUM} (${WIFI_WIDTH} MHz width)"
    echo "  ${BOLD}Signal:${NC}   ${WIFI_RSSI}"
    echo "  ${BOLD}Full:${NC}     ${WIFI_CHANNEL}"
    echo
    
    # AWDL Info
    echo "${GREEN}${BOLD}AWDL Interface (awdl0):${NC}"
    if [[ $AWDL_CHANNEL_COUNT -eq 1 ]]; then
        echo "  ${BOLD}Status:${NC}   ${GREEN}Synchronized (not hopping)${NC}"
        echo "  ${BOLD}Channel:${NC}  ${AWDL_CHAN_NUM}"
    else
        echo "  ${BOLD}Status:${NC}   ${YELLOW}Frequency Hopping${NC}"
        echo "  ${BOLD}Channels:${NC} ${AWDL_UNIQUE_CHANNELS}"
    fi
    echo "  ${BOLD}Sequence:${NC} ${AWDL_SEQUENCE:0:80}..."
    echo
    
    # Analysis
    echo "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}${BOLD}         Interference Analysis${NC}"
    echo "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo
    
    if [[ "$WIFI_CHAN_NUM" == "$AWDL_CHAN_NUM" ]]; then
        echo "${GREEN}${BOLD}✓ OPTIMAL CONFIGURATION${NC}"
        echo "${GREEN}WiFi and AWDL are synchronized on channel ${WIFI_CHAN_NUM}${NC}"
        echo "${GREEN}No stuttering or ping spikes expected.${NC}"
        
        # Reset notification state when channels match
        LAST_NOTIFIED_STATE=""
    else
        echo "${RED}${BOLD}⚠ INTERFERENCE DETECTED${NC}"
        echo "${RED}WiFi Channel: ${WIFI_CHAN_NUM} | AWDL Channel: ${AWDL_CHAN_NUM}${NC}"
        echo "${YELLOW}This WILL cause ping spikes and stuttering!${NC}"
        echo
        echo "${YELLOW}${BOLD}ACTION REQUIRED:${NC}"
        
        # Determine recommendation message
        local RECOMMENDATION=""
        if [[ "$WIFI_BAND" == "5" ]]; then
            echo "  → Change router to channel ${AWDL_CHAN_NUM} on 5GHz"
            echo "  → Channel 149 is typically preferred by AWDL on 5GHz"
            RECOMMENDATION="Change your router's 5 GHz WiFi channel to ${AWDL_CHAN_NUM} to match AWDL and prevent lag spikes."
        elif [[ "$WIFI_BAND" == "6" ]]; then
            echo "  → Change router to channel ${AWDL_CHAN_NUM} on 6GHz"
            echo "  → 6GHz AWDL commonly uses: 5, 21, 37, 53, 69, 85, 101, etc."
            RECOMMENDATION="Change your router's 6 GHz WiFi channel to ${AWDL_CHAN_NUM} to match AWDL and prevent lag spikes."
        else
            echo "  → Switch to 5GHz or 6GHz for better performance"
            RECOMMENDATION="Switch to 5 GHz (channel 149) or 6 GHz for better performance."
        fi
        
        # Show notification popup if this is a new mismatch
        local CURRENT_STATE="${WIFI_CHAN_NUM}-${AWDL_CHAN_NUM}"
        if [[ "$LAST_NOTIFIED_STATE" != "$CURRENT_STATE" ]]; then
            show_notification "$RECOMMENDATION"
            LAST_NOTIFIED_STATE="$CURRENT_STATE"
        fi
        
        # Play system alert sound
        afplay /System/Library/Sounds/Ping.aiff 2>/dev/null &
    fi
    echo
    
    # Band-specific recommendations
    echo "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}${BOLD}         Recommendations${NC}"
    echo "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo
    
    case "$WIFI_BAND" in
        2)
            echo "${RED}⚠ 2.4 GHz - NOT RECOMMENDED${NC}"
            echo "  • High interference from neighbors and devices"
            echo "  • AWDL operates on 5/6 GHz causing channel mismatch"
            echo "  • Switch to 5 GHz channel 149 or 6 GHz"
            ;;
        5)
            echo "${GREEN}✓ 5 GHz - GOOD CHOICE${NC}"
            echo "  • Best channel: 149 (AWDL's preferred channel)"
            echo "  • Alternative: Match AWDL's current channel (${AWDL_CHAN_NUM})"
            echo "  • Avoid: 36-48 (DFS channels cause switching)"
            ;;
        6)
            echo "${GREEN}✓ 6 GHz - EXCELLENT CHOICE${NC}"
            echo "  • Current AWDL channel: ${AWDL_CHAN_NUM}"
            echo "  • Match your router to this channel"
            echo "  • 6 GHz has minimal interference"
            echo "  • AWDL on 6 GHz may use: 5, 21, 37, 53, 69, 85, 101, etc."
            ;;
    esac
    echo
}

# Main loop
if [[ "$CONTINUOUS" == "true" ]]; then
    while true; do
        get_channel_info
        display_status
        sleep $INTERVAL
    done
else
    get_channel_info
    display_status
fi
