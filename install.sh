#!/bin/zsh
#
# AWDL Monitor Installation Script
# Installs the AWDL channel monitor as a background service that runs at startup
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_NAME="com.nologik.awdl-monitor.plist"
PLIST_SOURCE="$SCRIPT_DIR/$PLIST_NAME"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_DEST="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo "${BOLD}${BLUE}         AWDL Monitor - Installation${NC}"
echo "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo

# Check if already installed
if [[ -f "$PLIST_DEST" ]]; then
    echo "${YELLOW}⚠ AWDL Monitor service is already installed.${NC}"
    echo
    echo "Would you like to:"
    echo "  1) Reinstall (stop, remove, and install fresh)"
    echo "  2) Cancel"
    echo
    read -r "choice?Enter choice (1 or 2): "
    
    if [[ "$choice" == "1" ]]; then
        echo
        echo "${YELLOW}Uninstalling existing service...${NC}"
        launchctl unload "$PLIST_DEST" 2>/dev/null
        rm -f "$PLIST_DEST"
        echo "${GREEN}✓ Existing service removed${NC}"
        echo
    else
        echo "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
fi

# Create LaunchAgents directory if it doesn't exist
if [[ ! -d "$LAUNCH_AGENTS_DIR" ]]; then
    echo "${BLUE}Creating LaunchAgents directory...${NC}"
    mkdir -p "$LAUNCH_AGENTS_DIR"
    echo "${GREEN}✓ Directory created${NC}"
    echo
fi

# Verify the plist file exists
if [[ ! -f "$PLIST_SOURCE" ]]; then
    echo "${RED}✗ Error: $PLIST_NAME not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Copy plist to LaunchAgents
echo "${BLUE}Installing service...${NC}"
cp "$PLIST_SOURCE" "$PLIST_DEST"

if [[ $? -eq 0 ]]; then
    echo "${GREEN}✓ Service file installed to $PLIST_DEST${NC}"
else
    echo "${RED}✗ Failed to copy plist file${NC}"
    exit 1
fi

# Set proper permissions
chmod 644 "$PLIST_DEST"

# Load the service
echo
echo "${BLUE}Starting service...${NC}"
launchctl load "$PLIST_DEST"

if [[ $? -eq 0 ]]; then
    echo "${GREEN}✓ Service started successfully${NC}"
else
    echo "${RED}✗ Failed to start service${NC}"
    echo "${YELLOW}Try running: launchctl load $PLIST_DEST${NC}"
    exit 1
fi

echo
echo "${BOLD}${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo "${BOLD}${GREEN}         Installation Complete!${NC}"
echo "${BOLD}${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo
echo "${GREEN}The AWDL Monitor is now running in the background.${NC}"
echo
echo "${BOLD}What it does:${NC}"
echo "  • Monitors WiFi and AWDL channels every 30 seconds"
echo "  • Shows popup alerts when channels don't match"
echo "  • Runs automatically at startup"
echo "  • Runs silently when channels are synchronized"
echo
echo "${BOLD}Log Files:${NC}"
echo "  • Output: ${BLUE}$SCRIPT_DIR/monitor.log${NC}"
echo "  • Errors: ${BLUE}$SCRIPT_DIR/monitor.error.log${NC}"
echo
echo "${BOLD}Useful Commands:${NC}"
echo "  • Check status:     ${BLUE}launchctl list | grep awdl-monitor${NC}"
echo "  • View logs:        ${BLUE}tail -f ~/awdl-mac-monitor/monitor.log${NC}"
echo "  • Stop service:     ${BLUE}launchctl unload $PLIST_DEST${NC}"
echo "  • Start service:    ${BLUE}launchctl load $PLIST_DEST${NC}"
echo "  • Uninstall:        ${BLUE}~/awdl-mac-monitor/uninstall.sh${NC}"
echo
echo "${BOLD}Manual Check:${NC}"
echo "  • Quick check:      ${BLUE}~/awdl-mac-monitor/check_awdl_channel.sh${NC}"
echo
echo "${YELLOW}Note: The monitor checks every 30 seconds. If your channels are${NC}"
echo "${YELLOW}mismatched, you should see a popup alert within 30 seconds.${NC}"
echo
