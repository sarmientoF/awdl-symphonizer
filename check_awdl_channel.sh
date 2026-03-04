#!/bin/zsh
#
# AWDL Channel Monitor
# Detects which band/channel AWDL is using and compares with WiFi connection
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo "${BLUE}         AWDL & WiFi Channel Monitor${NC}"
echo "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo

# Get AWDL and WiFi info
WDUTIL_OUTPUT=$(sudo wdutil info 2>/dev/null)

if [[ -z "$WDUTIL_OUTPUT" ]]; then
    echo "${RED}Error: Failed to run 'sudo wdutil info'. Are you running with sudo?${NC}"
    exit 1
fi

# Use grep to extract specific fields directly from wdutil output
# WiFi channel is the one with format like "5g44/160"
WIFI_CHANNEL=$(echo "$WDUTIL_OUTPUT" | grep "Channel" | grep "[0-9]g[0-9]" | head -1 | awk '{print $NF}')
WIFI_BAND=$(echo "$WIFI_CHANNEL" | sed -n 's/\([0-9]\)g.*/\1/p')
WIFI_CHAN_NUM=$(echo "$WIFI_CHANNEL" | sed -n 's/.*g\([0-9]*\).*/\1/p')

# AWDL fields — grep directly
AWDL_ENABLED=$(echo "$WDUTIL_OUTPUT" | grep "AWDL Enabled" | awk '{print $NF}')
AWDL_SEQUENCE=$(echo "$WDUTIL_OUTPUT" | grep "Channel Sequence" | sed 's/.*: //')
AWDL_SCHEDULE=$(echo "$WDUTIL_OUTPUT" | grep "Schedule State" | sed 's/.*: //')

# Parse AWDL channels — filter out zeros and n/a
AWDL_CHAN_NUM=""
if [[ "$AWDL_ENABLED" == "Yes" && "$AWDL_SEQUENCE" != "n/a" && -n "$AWDL_SEQUENCE" ]]; then
    # Get unique non-zero channels from sequence (e.g., "44++ 44++ 6 44++" → "44 6")
    AWDL_CHANNELS=$(echo "$AWDL_SEQUENCE" | tr ' ' '\n' | sed 's/++//g' | grep -v '^0$' | sort -un | tr '\n' ' ' | sed 's/ *$//')
    # Primary channel = most frequent non-zero channel
    AWDL_CHAN_NUM=$(echo "$AWDL_SEQUENCE" | tr ' ' '\n' | sed 's/++//g' | grep -v '^0$' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
fi

# Display WiFi Info
echo "${GREEN}WiFi Interface (en0):${NC}"
if [[ -n "$WIFI_CHAN_NUM" ]]; then
    echo "  Band: ${WIFI_BAND} GHz"
    echo "  Channel: ${WIFI_CHAN_NUM}"
    echo "  Full: ${WIFI_CHANNEL}"
else
    echo "  ${YELLOW}Not connected${NC}"
fi
echo

# Display AWDL Info
echo "${GREEN}AWDL Interface (awdl0):${NC}"
if [[ "$AWDL_ENABLED" != "Yes" ]]; then
    echo "  ${YELLOW}AWDL is disabled${NC}"
    echo "  Enable AirDrop/Handoff to activate AWDL"
elif [[ -z "$AWDL_CHAN_NUM" ]]; then
    echo "  ${YELLOW}AWDL is enabled but not active (no channel assigned)${NC}"
    echo "  Schedule State: ${AWDL_SCHEDULE}"
else
    echo "  Channel Sequence: ${AWDL_SEQUENCE}"
    echo "  Primary Channel: ${AWDL_CHAN_NUM}"
    if [[ -n "$AWDL_CHANNELS" ]]; then
        echo "  All Channels: ${AWDL_CHANNELS}"
    fi
fi
echo

# Check for potential interference
echo "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo "${BLUE}         Analysis${NC}"
echo "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo

if [[ -z "$WIFI_CHAN_NUM" ]]; then
    echo "${YELLOW}⚠ WiFi not connected — cannot analyze${NC}"
elif [[ "$AWDL_ENABLED" != "Yes" || -z "$AWDL_CHAN_NUM" ]]; then
    echo "${GREEN}✓ AWDL is inactive — no channel hopping interference${NC}"
    echo "  Note: AWDL will activate when AirDrop/Handoff/AirPlay is used"
elif [[ "$WIFI_CHAN_NUM" == "$AWDL_CHAN_NUM" ]]; then
    echo "${GREEN}✓ OPTIMAL: WiFi and AWDL are on the SAME channel (${WIFI_CHAN_NUM})${NC}"
    echo "${GREEN}  No channel hopping needed — minimal interference.${NC}"
else
    echo "${RED}⚠ WARNING: WiFi and AWDL are on DIFFERENT channels!${NC}"
    echo "${RED}  WiFi: ${WIFI_CHAN_NUM} | AWDL: ${AWDL_CHAN_NUM}${NC}"
    echo "${YELLOW}  This causes ping spikes during AWDL channel hops.${NC}"
    echo
    echo "${YELLOW}Recommendation:${NC}"
    echo "  Change your router's 5GHz channel to ${AWDL_CHAN_NUM}"
fi
echo

# Additional recommendations
echo "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo "${BLUE}         Tips${NC}"
echo "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo
echo "${GREEN}Goal:${NC} Match your router channel to AWDL's preferred channel"
echo "  AWDL social channels: 6 (2.4GHz), 44 or 149 (5GHz)"
echo "  The preferred channel varies by region and device"
echo "  Run this tool with AWDL active to see which one your Mac uses"
echo
echo "${YELLOW}Note:${NC} '++' in channel sequence means extended availability windows"
echo "      '0' entries are idle slots (no hopping occurs)"
echo
