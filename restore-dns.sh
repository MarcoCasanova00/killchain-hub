#!/bin/bash
# DNS Restoration Script for Killchain-Hub
# Use this if evasion mode broke your system DNS

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== DNS Restoration Utility ===${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script requires root privileges!${NC}"
    echo "Run: sudo ./restore-dns.sh"
    exit 1
fi

# Display current DNS
CURRENT_DNS=$(grep nameserver /etc/resolv.conf 2>/dev/null | head -n1 | awk '{print $2}')
echo -e "${YELLOW}Current DNS server: ${CYAN}$CURRENT_DNS${NC}\n"

# Check if anonymized
if [ "$CURRENT_DNS" = "127.0.0.1" ]; then
    echo -e "${GREEN}✓ DNS is currently anonymized (routing through Tor)${NC}\n"
else
    echo -e "${YELLOW}⚠ DNS is NOT anonymized (may be leaking to ISP)${NC}\n"
fi

# Warning
echo -e "${RED}⚠️  WARNING - DE-ANONYMIZATION RISK ⚠️${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Restoring DNS will:"
echo "  • Allow your system to resolve domain names normally"
echo "  • Re-enable access to package managers (apt/yum)"
echo "  • Allow git, curl, wget to work with domain names"
echo ""
echo -e "${RED}BUT it will also:${NC}"
echo "  • Expose DNS queries to your ISP or VPS provider"
echo "  • Potentially leak your real location/identity"
echo "  • Bypass Tor for DNS resolution"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Ask for confirmation
echo -ne "Do you want to restore DNS? (y/N): "
read -r CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "\n${GREEN}Aborted. DNS remains anonymized.${NC}"
    exit 0
fi

echo ""

# Try to restore from backup first
if [ -f /etc/resolv.conf.backup ]; then
    echo -e "${YELLOW}[1/2] Restoring from backup...${NC}"
    cp /etc/resolv.conf.backup /etc/resolv.conf
    echo -e "${GREEN}✓ DNS restored from backup${NC}"
else
    echo -e "${YELLOW}[1/2] No backup found. Using fallback DNS...${NC}"
    
    # Detect VPS provider and use appropriate DNS
    if grep -qi "google" /sys/class/dmi/id/product_name 2>/dev/null || grep -qi "google" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
        # Google Cloud Platform
        FALLBACK_DNS="169.254.169.254"
        echo -e "${CYAN}Google Cloud detected - using metadata DNS${NC}"
    elif grep -qi "amazon\|aws" /sys/class/dmi/id/product_name 2>/dev/null; then
        # AWS
        FALLBACK_DNS="169.254.169.253"
        echo -e "${CYAN}AWS detected - using VPC DNS${NC}"
    else
        # Generic fallback (Google Public DNS)
        FALLBACK_DNS="8.8.8.8"
        echo -e "${CYAN}Using Google Public DNS as fallback${NC}"
    fi
    
    echo "nameserver $FALLBACK_DNS" > /etc/resolv.conf
    echo -e "${GREEN}✓ DNS set to $FALLBACK_DNS${NC}"
fi

# Verify restoration
echo -e "\n${YELLOW}[2/2] Verifying DNS resolution...${NC}"
if timeout 5 nslookup google.com >/dev/null 2>&1 || timeout 5 host google.com >/dev/null 2>&1; then
    NEW_DNS=$(grep nameserver /etc/resolv.conf 2>/dev/null | head -n1 | awk '{print $2}')
    echo -e "${GREEN}✓ DNS is working! (using $NEW_DNS)${NC}"
else
    echo -e "${RED}✗ DNS still not working. Manual intervention needed.${NC}"
    echo "Try: echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf"
    exit 1
fi

echo ""
echo -e "${GREEN}=== DNS Restoration Complete ===${NC}"
echo -e "${RED}⚠ You are NO LONGER anonymized for DNS queries!${NC}"
echo -e "${YELLOW}→ To re-anonymize: run killchain-hub → Option 5 → Option 2${NC}"
echo ""
