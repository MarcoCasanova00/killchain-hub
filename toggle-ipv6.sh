#!/bin/bash
# IPv6 Toggle Script for Killchain-Hub
# Use this for rare cases when you need to test IPv6-specific vulnerabilities

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script requires root privileges!${NC}"
    echo "Run: sudo ./toggle-ipv6.sh"
    exit 1
fi

# Check current IPv6 status
IPV6_STATUS=$(sysctl net.ipv6.conf.all.disable_ipv6 2>/dev/null | awk '{print $3}')

echo -e "${CYAN}=== IPv6 Toggle Utility ===${NC}\n"

if [ "$IPV6_STATUS" = "1" ]; then
    echo -e "${GREEN}✓ IPv6 is currently DISABLED (secure)${NC}"
    echo -e "Your system is protected from IPv6 leaks.\n"
    
    echo -e "${RED}⚠️  WARNING - IPv6 LEAK RISK ⚠️${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Enabling IPv6 will:"
    echo "  • Allow IPv6-specific pentesting (e.g., IPv6 scans)"
    echo "  • Enable testing of dual-stack targets"
    echo ""
    echo -e "${RED}BUT it will also:${NC}"
    echo "  • Expose your real IPv6 address"
    echo "  • Create a de-anonymization vector (Tor is IPv4-only)"
    echo "  • Bypass Tor for IPv6 traffic"
    echo ""
    echo -e "${YELLOW}Only enable if you're testing IPv6-specific vulnerabilities!${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    echo -ne "Enable IPv6? (y/N): "
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "\n${YELLOW}Enabling IPv6...${NC}"
        sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null
        sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null
        echo -e "${GREEN}✓ IPv6 enabled${NC}"
        
        # Verify
        if ip -6 addr show | grep -q "inet6"; then
            IPV6_ADDR=$(ip -6 addr show | grep "inet6" | grep -v "::1" | head -n1 | awk '{print $2}')
            echo -e "${CYAN}IPv6 address: $IPV6_ADDR${NC}"
        fi
        
        echo -e "\n${RED}⚠ Remember to disable IPv6 after testing!${NC}"
        echo -e "${YELLOW}→ Run: sudo ./toggle-ipv6.sh${NC}"
    else
        echo -e "\n${GREEN}Cancelled. IPv6 remains disabled.${NC}"
    fi
    
else
    echo -e "${RED}✗ IPv6 is currently ENABLED (leak risk!)${NC}"
    echo -e "Your system may be leaking IPv6 traffic outside Tor.\n"
    
    # Show current IPv6 address if any
    if ip -6 addr show | grep -q "inet6" && ip -6 addr show | grep -v "::1" | grep -q "inet6"; then
        IPV6_ADDR=$(ip -6 addr show | grep "inet6" | grep -v "::1" | head -n1 | awk '{print $2}')
        echo -e "${YELLOW}Current IPv6: ${CYAN}$IPV6_ADDR${NC}\n"
    fi
    
    echo -ne "Disable IPv6 to prevent leaks? (Y/n): "
    read -r CONFIRM
    
    if [[ ! "$CONFIRM" =~ ^[Nn]$ ]]; then
        echo -e "\n${YELLOW}Disabling IPv6...${NC}"
        sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null
        sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null
        echo -e "${GREEN}✓ IPv6 disabled${NC}"
        echo -e "${GREEN}✓ System is now protected from IPv6 leaks${NC}"
    else
        echo -e "\n${YELLOW}IPv6 remains enabled. Be aware of leak risks!${NC}"
    fi
fi

echo ""
