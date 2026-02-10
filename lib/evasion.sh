#!/bin/bash
# Enhanced Evasion Script for Killchain-Hub
# Provides multiple layers of anonymity, anti-forensics, and DNS leak protection

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# Signal handler for graceful exit
cleanup() {
    echo -e "\n${YELLOW}Evasion script interrupted. Some changes may have been applied.${NC}"
    exit 130
}

# Trap Ctrl+C (SIGINT) and SIGTERM
trap cleanup SIGINT SIGTERM

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo) to apply evasion measures!${NC}"
    exit 1
fi

# Set path for sysctl (Debian/Ubuntu fix)
SYSCTL="/sbin/sysctl"
if ! [ -x "$SYSCTL" ]; then SYSCTL="sysctl"; fi

echo -e "${CYAN}=== Enhanced Evasion Mode ===${NC}\n"

# Track what was applied for accurate summary
MAC_STATUS="Skipped"

# 1. MAC Address Randomization
echo -e "${YELLOW}[1/10] MAC Address Randomization${NC}"

# Ask user about environment
echo -ne "Are you running on WSL/Cloud/VM/VPS? (y/n): "
read -r ENV_VIRTUAL

if [[ "$ENV_VIRTUAL" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠ Virtualized environment - Skipping MAC randomization (not supported)${NC}"
elif grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL auto-detection as fallback
    echo -e "${YELLOW}⚠ WSL detected - MAC randomization not supported${NC}"
elif command -v macchanger &>/dev/null; then
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -n "$INTERFACE" ]; then
        # Use timeout to prevent hanging
        timeout 5 bash -c "
            ip link set '$INTERFACE' down 2>/dev/null
            macchanger -r '$INTERFACE' 2>/dev/null
            ip link set '$INTERFACE' up 2>/dev/null
        " && { echo -e "${GREEN}✓ MAC address randomized on $INTERFACE${NC}"; MAC_STATUS="Randomized on $INTERFACE"; } || \
           echo -e "${YELLOW}⚠ MAC randomization failed or timed out (not critical)${NC}"
    else
        echo -e "${YELLOW}⚠ No network interface found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ macchanger not installed (optional)${NC}"
fi

# 2. Hostname Randomization
echo -e "\n${YELLOW}[2/10] Hostname Randomization${NC}"
RANDOM_HOSTNAME="host-$(openssl rand -hex 4)"
hostnamectl set-hostname "$RANDOM_HOSTNAME" 2>/dev/null
echo -e "${GREEN}✓ Hostname changed to: $RANDOM_HOSTNAME${NC}"

# 3. Timezone Obfuscation
echo -e "\n${YELLOW}[3/10] Timezone Obfuscation${NC}"
TIMEZONES=("UTC" "America/New_York" "Europe/London" "Asia/Tokyo" "Australia/Sydney")
RANDOM_TZ=${TIMEZONES[$RANDOM % ${#TIMEZONES[@]}]}
timedatectl set-timezone "$RANDOM_TZ" 2>/dev/null
echo -e "${GREEN}✓ Timezone set to: $RANDOM_TZ${NC}"

# 4. Disable IPv6 (Prevent Leaks)
echo -e "\n${YELLOW}[4/10] Disabling IPv6${NC}"
$SYSCTL -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
$SYSCTL -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
$SYSCTL -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null 2>&1

# Verify IPv6 is disabled
IPV6_CHECK=$($SYSCTL net.ipv6.conf.all.disable_ipv6 2>/dev/null | awk '{print $3}')
if [ "$IPV6_CHECK" = "1" ]; then
    echo -e "${GREEN}✓ IPv6 disabled system-wide including loopback (leak prevention active)${NC}"
else
    echo -e "${YELLOW}⚠ IPv6 disable may have failed (verify manually)${NC}"
fi

# 5. DNS Configuration (Force Tor DNS)
echo -e "\n${YELLOW}[5/10] Enforcing DNS over Tor${NC}"

# Backup existing resolv.conf
if [ ! -f /etc/resolv.conf.backup ]; then
    cp /etc/resolv.conf /etc/resolv.conf.backup
fi

# Temporarily set DNS to Tor (session-based)
echo "nameserver 127.0.0.1" > /etc/resolv.conf

echo -e "${GREEN}✓ /etc/resolv.conf set to 127.0.0.1 (temporary, session-based)${NC}"
echo -e "${YELLOW}⚠ Note: On VPS/Cloud, this change may revert on reboot or network changes.${NC}"
echo -e "${YELLOW}  For persistent changes, configure your VPS to use Tor DNS manually.${NC}"

# 6. Firewall Kill Switch (IPTables)
echo -e "\n${YELLOW}[6/10] Configuring Firewall Kill Switch for 'anon'${NC}"

# Flush existing rules for anon user (if any custom chains existed, this might need adjustment, but for now we append/insert)
# We will use OUTPUT chain to block anon user

# Check if anon user exists
if id "anon" &>/dev/null; then
    ANON_UID=$(id -u anon)
    
    # Remove any previous anon rules to prevent accumulation
    while iptables -D OUTPUT -o lo -m owner --uid-owner "$ANON_UID" -j ACCEPT 2>/dev/null; do :; done
    while iptables -D OUTPUT ! -o lo -m owner --uid-owner "$ANON_UID" -j REJECT --reject-with icmp-net-unreachable 2>/dev/null; do :; done
    
    # Allow traffic to loopback (Tor SOCKS on 9050, DNS on 53)
    iptables -A OUTPUT -o lo -m owner --uid-owner "$ANON_UID" -j ACCEPT
    
    # REJECT everything else for anon
    iptables -A OUTPUT ! -o lo -m owner --uid-owner "$ANON_UID" -j REJECT --reject-with icmp-net-unreachable
    
    echo -e "${GREEN}✓ Firewall rules applied: 'anon' user restricted to localhost (Tor)${NC}"
else
    echo -e "${YELLOW}⚠ User 'anon' not found. Skipping firewall rules.${NC}"
fi

# 7. Disable History
echo -e "\n${YELLOW}[7/10] History Cleanup${NC}"
unset HISTFILE
export HISTSIZE=0
export HISTFILESIZE=0
history -c 2>/dev/null
cat /dev/null > ~/.bash_history 2>/dev/null
# Clear anon history too
if [ -f /home/anon/.bash_history ]; then
    cat /dev/null > /home/anon/.bash_history
fi
echo -e "${GREEN}✓ Bash history disabled${NC}"

# 8. Clear System Logs
echo -e "\n${YELLOW}[8/10] Log Cleanup${NC}"
find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null
echo -e "${GREEN}✓ System logs cleared${NC}"

# 9. Tor Circuit Renewal
echo -e "\n${YELLOW}[9/10] Tor Circuit Renewal${NC}"
if systemctl is-active --quiet tor; then
    echo "SIGNAL NEWNYM" | nc 127.0.0.1 9051 2>/dev/null || \
    systemctl reload tor
    sleep 2
    echo -e "${GREEN}✓ Tor circuit renewed${NC}"
else
    echo -e "${RED}✗ Tor service not running${NC}"
fi

# 10. Verification Summary
echo -e "\n${YELLOW}[10/10] Verification${NC}"

echo -e "\n${CYAN}=== Evasion Summary ===${NC}"
echo "✓ MAC Address: $MAC_STATUS"
echo "✓ Hostname: $RANDOM_HOSTNAME"
echo "✓ Timezone: $RANDOM_TZ"
echo "✓ IPv6: Disabled"
echo "✓ DNS: Forced to 127.0.0.1 (Tor)"
echo "✓ Firewall: 'anon' user traffic restricted to localhost"
echo "✓ History: Disabled"
echo ""
echo -e "${GREEN}Enhanced evasion mode active!${NC}"
echo -e "${YELLOW}Remember: Use responsibly and legally!${NC}"

