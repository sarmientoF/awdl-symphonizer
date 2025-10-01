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

# Extract WiFi channel (format: 5g149/80 or 6g37/160)
WIFI_CHANNEL=$(echo "$WDUTIL_OUTPUT" | grep "^    Channel " | awk '{print $3}')
# Extract band (the number before 'g')
WIFI_BAND=$(echo "$WIFI_CHANNEL" | sed -n 's/\([0-9]\)g.*/\1/p')
# Extract channel number (between 'g' and '/')
WIFI_CHAN_NUM=$(echo "$WIFI_CHANNEL" | sed -n 's/.*g\([0-9]*\).*/\1/p')

# Extract AWDL channel sequence
AWDL_SEQUENCE=$(echo "$WDUTIL_OUTPUT" | grep "^    Channel Sequence" | sed 's/.*: //')
# Get the most common channel from sequence (first one usually)
AWDL_CHANNEL=$(echo "$AWDL_SEQUENCE" | awk '{print $1}' | sed 's/++//g')

# Determine band from channel number
determine_band() {
    local chan=$1
    if [[ $chan -le 14 ]]; then
        echo "2"
    elif [[ $chan -ge 36 && $chan -le 165 ]]; then
        echo "5"
    elif [[ $chan -ge 1 && $chan -le 233 ]]; then
        # Could be 6GHz if context suggests it
        # Check if it's in the format like "6g149"
        echo "6"
    else
        echo "unknown"
    fi
}

# If AWDL channel doesn't have band prefix, try to determine it
if [[ ! "$AWDL_CHANNEL" =~ ^[0-9]+$ ]]; then
    AWDL_BAND=$(echo "$AWDL_CHANNEL" | sed 's/[0-9]//g')
    AWDL_CHAN_NUM=$(echo "$AWDL_CHANNEL" | sed 's/[^0-9]//g')
else
    AWDL_CHAN_NUM=$AWDL_CHANNEL
    AWDL_BAND=$(determine_band $AWDL_CHAN_NUM)
fi

# Display WiFi Info
echo "${GREEN}WiFi Interface (en0):${NC}"
echo "  Band: ${WIFI_BAND}GHz"
echo "  Channel: ${WIFI_CHAN_NUM}"
echo "  Full: ${WIFI_CHANNEL}"
echo

# Display AWDL Info
echo "${GREEN}AWDL Interface (awdl0):${NC}"
echo "  Channel Sequence: ${AWDL_SEQUENCE}"
echo "  Primary Channel: ${AWDL_CHANNEL}"
if [[ -n "$AWDL_BAND" ]]; then
    echo "  Detected Band: ${AWDL_BAND}GHz"
fi
echo

# Check for potential interference
echo "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo "${BLUE}         Analysis${NC}"
echo "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo

if [[ "$WIFI_CHAN_NUM" == "$AWDL_CHAN_NUM" ]]; then
    echo "${GREEN}✓ OPTIMAL: WiFi and AWDL are on the SAME channel (${WIFI_CHAN_NUM})${NC}"
    echo "${GREEN}  This minimizes interference and prevents stuttering.${NC}"
else
    echo "${RED}⚠ WARNING: WiFi and AWDL are on DIFFERENT channels!${NC}"
    echo "${RED}  WiFi: ${WIFI_CHAN_NUM} | AWDL: ${AWDL_CHAN_NUM}${NC}"
    echo "${YELLOW}  This may cause ping spikes and stuttering.${NC}"
    echo
    echo "${YELLOW}Recommendation:${NC}"
    if [[ "$WIFI_BAND" == "5" ]]; then
        echo "  Change your router to channel ${AWDL_CHAN_NUM} (5GHz)"
    elif [[ "$WIFI_BAND" == "6" ]]; then
        echo "  For 6GHz, AWDL typically uses channels in the lower range"
        echo "  Consider using channel ${AWDL_CHAN_NUM} on your router"
    else
        echo "  For 2.4GHz, consider switching to 5GHz or 6GHz for better performance"
    fi
fi
echo

# Additional recommendations
echo "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo "${BLUE}         Recommendations by Band${NC}"
echo "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo
echo "${GREEN}2.4 GHz:${NC} Not recommended for gaming (high interference)"
echo "${GREEN}5 GHz:${NC}   Use channel 149 (AWDL's preferred channel)"
echo "${GREEN}6 GHz:${NC}   AWDL can use various channels - match your router to AWDL"
echo
echo "${YELLOW}Note:${NC} If AWDL shows '149++', it's hopping but staying on channel 149"
echo "      The '++' indicates extended availability windows on that channel"
echo
