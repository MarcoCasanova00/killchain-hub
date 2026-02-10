#!/bin/sh
# DNS Restoration Script for Killchain-Hub
# Use this if evasion mode broke your system DNS
# Optimized for POSIX sh and bash compatibility on Debian/Arch/etc.

# Colors (standard POSIX echo doesn't support -e, so we use printf)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_msg() {
    printf "${2}%s${NC}\n" "$1"
}

log_msg "=== DNS Restoration Utility ===" "${CYAN}"
printf "\n"

# Check if running as root
# Use id -u for portability (EUID is bash-only)
if [ "$(id -u)" != "0" ]; then
    log_msg "This script requires root privileges!" "${RED}"
    printf "Run: sudo %s\n" "$0"
    exit 1
fi

# Display current DNS
CURRENT_DNS=$(grep nameserver /etc/resolv.conf 2>/dev/null | head -n1 | awk '{print $2}')
printf "${YELLOW}Current DNS server: ${CYAN}%s${NC}\n\n" "$CURRENT_DNS"

# Check if anonymized
if [ "$CURRENT_DNS" = "127.0.0.1" ]; then
    log_msg "✓ DNS is currently anonymized (routing through Tor)" "${GREEN}"
else
    log_msg "⚠ DNS is NOT anonymized (may be leaking to ISP)" "${YELLOW}"
fi
printf "\n"

# Warning
log_msg "⚠️  WARNING - DE-ANONYMIZATION RISK ⚠️" "${RED}"
log_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "${YELLOW}"
printf "Restoring DNS will:\n"
printf "  • Allow your system to resolve domain names normally\n"
printf "  • Re-enable access to package managers (apt/yum)\n"
printf "  • Allow git, curl, wget to work with domain names\n\n"

log_msg "BUT it will also:" "${RED}"
printf "  • Expose DNS queries to your ISP or VPS provider\n"
printf "  • Potentially leak your real location/identity\n"
printf "  • Bypass Tor for DNS resolution\n\n"

log_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "${YELLOW}"
printf "\n"

# Ask for confirmation
printf "Do you want to restore DNS? (y/N): "
read -r CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    printf "\n"
    log_msg "Aborted. DNS remains anonymized." "${GREEN}"
    exit 0
fi

printf "\n"

# Try to restore from backup first
if [ -f /etc/resolv.conf.backup ]; then
    log_msg "[1/2] Restoring from backup..." "${YELLOW}"
    cp /etc/resolv.conf.backup /etc/resolv.conf
    log_msg "✓ DNS restored from backup" "${GREEN}"
else
    log_msg "[1/2] No backup found. Using fallback DNS..." "${YELLOW}"
    
    # Detect VPS provider and use appropriate DNS
    if grep -qi "google" /sys/class/dmi/id/product_name 2>/dev/null || grep -qi "google" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
        # Google Cloud Platform
        FALLBACK_DNS="169.254.169.254"
        log_msg "Google Cloud detected - using metadata DNS" "${CYAN}"
    elif [ -f /sys/class/dmi/id/product_name ] && grep -qi "amazon\|aws" /sys/class/dmi/id/product_name 2>/dev/null; then
        # AWS
        FALLBACK_DNS="169.254.169.253"
        log_msg "AWS detected - using VPC DNS" "${CYAN}"
    else
        # Generic fallback (Google Public DNS)
        FALLBACK_DNS="8.8.8.8"
        log_msg "Using Google Public DNS as fallback" "${CYAN}"
    fi
    
    printf "nameserver %s\n" "$FALLBACK_DNS" > /etc/resolv.conf
    log_msg "✓ DNS set to $FALLBACK_DNS" "${GREEN}"
fi

# Verify restoration
printf "\n"
log_msg "[2/2] Verifying DNS resolution..." "${YELLOW}"
# Use command -v to check for availability
if command -v nslookup >/dev/null 2>&1; then
    DNS_TOOL="nslookup google.com"
elif command -v host >/dev/null 2>&1; then
    DNS_TOOL="host google.com"
else
    DNS_TOOL="ping -c 1 8.8.8.8" # Last resort
fi

if $DNS_TOOL >/dev/null 2>&1; then
    NEW_DNS=$(grep nameserver /etc/resolv.conf 2>/dev/null | head -n1 | awk '{print $2}')
    log_msg "✓ DNS is working! (using $NEW_DNS)" "${GREEN}"
else
    log_msg "✗ DNS still not working. Manual intervention needed." "${RED}"
    printf "Try: echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf\n"
    exit 1
fi

printf "\n"
log_msg "=== DNS Restoration Complete ===" "${GREEN}"
log_msg "⚠ You are NO LONGER anonymized for DNS queries!" "${RED}"
log_msg "→ To re-anonymize: run killchain-hub → Option 5 → Option 2" "${YELLOW}"
printf "\n"
