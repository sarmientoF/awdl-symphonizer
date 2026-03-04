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
    local ROUTER_IP=$(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')
    ROUTER_IP=${ROUTER_IP:-"192.168.1.1"}

    osascript <<EOF >/dev/null 2>&1 &
tell application "System Events"
    display notification "$MESSAGE" with title "⚠️ AWDL Channel Mismatch" subtitle "WiFi: Ch ${WIFI_CHAN_NUM} | AWDL: Ch ${AWDL_CHAN_NUM}" sound name "Ping"
end tell
EOF

    osascript <<EOF >/dev/null 2>&1 &
tell application "System Events"
    activate
    display dialog "⚠️ AWDL CHANNEL MISMATCH DETECTED\n\nYour WiFi and AWDL are on different channels, causing lag spikes.\n\nCurrent Status:\n• WiFi Channel: ${WIFI_CHAN_NUM} (${WIFI_BAND} GHz)\n• AWDL Channel: ${AWDL_CHAN_NUM}\n\nFix:\n$MESSAGE" buttons {"Dismiss", "Open Router"} default button "Open Router" with title "AWDL Channel Monitor" with icon caution giving up after 60

    if button returned of result is "Open Router" then
        open location "http://${ROUTER_IP}"
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
    local WDUTIL_OUTPUT=$(sudo wdutil info 2>/dev/null)

    # WiFi channel is the one with format like "5g44/160"
    WIFI_CHANNEL=$(echo "$WDUTIL_OUTPUT" | grep "Channel" | grep "[0-9]g[0-9]" | head -1 | awk '{print $NF}')
    WIFI_BAND=$(echo "$WIFI_CHANNEL" | sed -n 's/\([0-9]\)g.*/\1/p')
    WIFI_CHAN_NUM=$(echo "$WIFI_CHANNEL" | sed -n 's/.*g\([0-9]*\).*/\1/p')
    WIFI_WIDTH=$(echo "$WIFI_CHANNEL" | sed -n 's/.*\/\([0-9]*\)/\1/p')

    # AWDL fields — grep directly
    AWDL_ENABLED=$(echo "$WDUTIL_OUTPUT" | grep "AWDL Enabled" | awk '{print $NF}')
    AWDL_SEQUENCE=$(echo "$WDUTIL_OUTPUT" | grep "Channel Sequence" | sed 's/.*: //')

    # Parse AWDL channels — filter out zeros and n/a
    AWDL_CHAN_NUM=""
    AWDL_UNIQUE_CHANNELS=""
    AWDL_CHANNEL_COUNT=0

    if [[ "$AWDL_ENABLED" == "Yes" && "$AWDL_SEQUENCE" != "n/a" && -n "$AWDL_SEQUENCE" ]]; then
        AWDL_UNIQUE_CHANNELS=$(echo "$AWDL_SEQUENCE" | tr ' ' '\n' | sed 's/++//g' | grep -v '^0$' | sort -un | tr '\n' ' ' | sed 's/ *$//')
        AWDL_CHANNEL_COUNT=$(echo "$AWDL_UNIQUE_CHANNELS" | wc -w | tr -d ' ')
        # Primary = most frequent non-zero channel
        AWDL_CHAN_NUM=$(echo "$AWDL_SEQUENCE" | tr ' ' '\n' | sed 's/++//g' | grep -v '^0$' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
    fi

    # Extract RSSI and SSID directly
    WIFI_RSSI=$(echo "$WDUTIL_OUTPUT" | grep "RSSI" | head -1 | sed 's/.*: //')
    WIFI_SSID=$(echo "$WDUTIL_OUTPUT" | grep "SSID" | head -1 | sed 's/.*: //')
}

display_status() {
    show_header

    # Timestamp
    echo "${CYAN}Last Updated: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo

    # WiFi Info
    echo "${GREEN}${BOLD}WiFi Interface (en0):${NC}"
    if [[ -n "$WIFI_CHAN_NUM" ]]; then
        echo "  ${BOLD}SSID:${NC}     ${WIFI_SSID}"
        echo "  ${BOLD}Band:${NC}     ${WIFI_BAND} GHz"
        echo "  ${BOLD}Channel:${NC}  ${WIFI_CHAN_NUM} (${WIFI_WIDTH} MHz width)"
        echo "  ${BOLD}Signal:${NC}   ${WIFI_RSSI}"
        echo "  ${BOLD}Full:${NC}     ${WIFI_CHANNEL}"
    else
        echo "  ${YELLOW}Not connected${NC}"
    fi
    echo

    # AWDL Info
    echo "${GREEN}${BOLD}AWDL Interface (awdl0):${NC}"
    if [[ "$AWDL_ENABLED" != "Yes" ]]; then
        echo "  ${BOLD}Status:${NC}   ${YELLOW}Disabled${NC}"
        echo "  Enable AirDrop/Handoff to activate AWDL"
    elif [[ -z "$AWDL_CHAN_NUM" ]]; then
        echo "  ${BOLD}Status:${NC}   ${YELLOW}Enabled but inactive (no channel)${NC}"
    elif [[ $AWDL_CHANNEL_COUNT -eq 1 ]]; then
        echo "  ${BOLD}Status:${NC}   ${GREEN}Synchronized (single channel)${NC}"
        echo "  ${BOLD}Channel:${NC}  ${AWDL_CHAN_NUM}"
    else
        echo "  ${BOLD}Status:${NC}   ${YELLOW}Multi-channel (hopping between ${AWDL_CHANNEL_COUNT} channels)${NC}"
        echo "  ${BOLD}Channels:${NC} ${AWDL_UNIQUE_CHANNELS}"
        echo "  ${BOLD}Primary:${NC}  ${AWDL_CHAN_NUM}"
    fi
    echo "  ${BOLD}Sequence:${NC} ${AWDL_SEQUENCE:0:60}..."
    echo

    # Analysis
    echo "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}${BOLD}         Interference Analysis${NC}"
    echo "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo

    if [[ -z "$WIFI_CHAN_NUM" ]]; then
        echo "${YELLOW}⚠ WiFi not connected — cannot analyze${NC}"
        LAST_NOTIFIED_STATE=""
    elif [[ "$AWDL_ENABLED" != "Yes" || -z "$AWDL_CHAN_NUM" ]]; then
        echo "${GREEN}✓ AWDL inactive — no channel hopping interference${NC}"
        echo "  AWDL will activate when AirDrop/Handoff/AirPlay is used"
        LAST_NOTIFIED_STATE=""
    elif [[ "$WIFI_CHAN_NUM" == "$AWDL_CHAN_NUM" ]]; then
        echo "${GREEN}${BOLD}✓ OPTIMAL CONFIGURATION${NC}"
        echo "${GREEN}WiFi and AWDL synchronized on channel ${WIFI_CHAN_NUM}${NC}"
        echo "${GREEN}No ping spikes expected from AWDL.${NC}"
        LAST_NOTIFIED_STATE=""
    else
        echo "${RED}${BOLD}⚠ CHANNEL MISMATCH${NC}"
        echo "${RED}WiFi: channel ${WIFI_CHAN_NUM} | AWDL: channel ${AWDL_CHAN_NUM}${NC}"
        echo "${YELLOW}This causes ping spikes during AWDL channel hops.${NC}"
        echo
        echo "${YELLOW}${BOLD}FIX:${NC}"
        echo "  → Change router's ${WIFI_BAND}GHz channel to ${AWDL_CHAN_NUM}"

        local RECOMMENDATION="Change router's ${WIFI_BAND} GHz channel to ${AWDL_CHAN_NUM}"

        # Show notification popup if this is a new mismatch
        local CURRENT_STATE="${WIFI_CHAN_NUM}-${AWDL_CHAN_NUM}"
        if [[ "$LAST_NOTIFIED_STATE" != "$CURRENT_STATE" ]]; then
            show_notification "$RECOMMENDATION"
            LAST_NOTIFIED_STATE="$CURRENT_STATE"
        fi
    fi
    echo

    # Recommendations
    echo "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo "${BLUE}${BOLD}         Tips${NC}"
    echo "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo

    case "$WIFI_BAND" in
        2)
            echo "${RED}⚠ 2.4 GHz — high interference, consider 5 or 6 GHz${NC}"
            ;;
        5)
            echo "${GREEN}✓ 5 GHz${NC}"
            echo "  AWDL social channels: 44 or 149 (varies by region)"
            if [[ -n "$AWDL_CHAN_NUM" ]]; then
                echo "  Your AWDL prefers: ${AWDL_CHAN_NUM} — set router to this"
            else
                echo "  Activate AWDL to detect preferred channel"
            fi
            ;;
        6)
            echo "${GREEN}✓ 6 GHz — minimal congestion${NC}"
            if [[ -n "$AWDL_CHAN_NUM" ]]; then
                echo "  Your AWDL uses: ${AWDL_CHAN_NUM} — match router to this"
            fi
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
