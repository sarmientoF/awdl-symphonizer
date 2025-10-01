#!/bin/zsh
#
# AWDL Monitor Uninstallation Script
# Removes the AWDL channel monitor background service
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Paths
PLIST_NAME="com.nologik.awdl-monitor.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"

echo "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo "${BOLD}${BLUE}         AWDL Monitor - Uninstallation${NC}"
echo "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo

# Check if service is installed
if [[ ! -f "$PLIST_DEST" ]]; then
    echo "${YELLOW}⚠ AWDL Monitor service is not installed.${NC}"
    echo "${YELLOW}Nothing to uninstall.${NC}"
    exit 0
fi

echo "${YELLOW}This will remove the AWDL Monitor background service.${NC}"
echo
read -r "confirm?Are you sure you want to continue? (y/N): "

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "${YELLOW}Uninstallation cancelled.${NC}"
    exit 0
fi

echo
echo "${BLUE}Stopping service...${NC}"
launchctl unload "$PLIST_DEST" 2>/dev/null

if [[ $? -eq 0 ]]; then
    echo "${GREEN}✓ Service stopped${NC}"
else
    echo "${YELLOW}⚠ Service was not running or already stopped${NC}"
fi

echo
echo "${BLUE}Removing service file...${NC}"
rm -f "$PLIST_DEST"

if [[ $? -eq 0 ]]; then
    echo "${GREEN}✓ Service file removed${NC}"
else
    echo "${RED}✗ Failed to remove service file${NC}"
    exit 1
fi

echo
echo "${BOLD}${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo "${BOLD}${GREEN}         Uninstallation Complete!${NC}"
echo "${BOLD}${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo
echo "${GREEN}The AWDL Monitor service has been removed.${NC}"
echo
echo "${BOLD}Note:${NC}"
echo "  • The scripts in ~/awdl-mac-monitor/ are still available"
echo "  • You can run them manually anytime:"
echo "    ${BLUE}~/awdl-mac-monitor/check_awdl_channel.sh${NC}"
echo "    ${BLUE}~/awdl-mac-monitor/monitor_awdl_live.sh${NC}"
echo
echo "  • To reinstall the service:"
echo "    ${BLUE}~/awdl-mac-monitor/install.sh${NC}"
echo
echo "  • To completely remove everything:"
echo "    ${BLUE}rm -rf ~/awdl-mac-monitor${NC}"
echo
