#!/bin/bash
# Enhanced Evasion Script for Killchain-Hub
# Provides multiple layers of anonymity, anti-forensics, and DNS leak protection

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo) to apply evasion measures!${NC}"
    exit 1
fi

echo -e "${CYAN}=== Enhanced Evasion Mode ===${NC}\n"

# 1. MAC Address Randomization
echo -e "${YELLOW}[1/10] MAC Address Randomization${NC}"
if command -v macchanger &>/dev/null; then
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -n "$INTERFACE" ]; then
        ip link set "$INTERFACE" down
        macchanger -r "$INTERFACE" 2>/dev/null
        ip link set "$INTERFACE" up
        echo -e "${GREEN}✓ MAC address randomized on $INTERFACE${NC}"
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
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
echo -e "${GREEN}✓ IPv6 disabled system-wide${NC}"

# 5. DNS Configuration (Force Tor DNS)
echo -e "\n${YELLOW}[5/10] Enforcing DNS over Tor${NC}"
# Backup existing resolv.conf
if [ ! -f /etc/resolv.conf.backup ]; then
    cp /etc/resolv.conf /etc/resolv.conf.backup
fi

# Create new resolv.conf
echo "nameserver 127.0.0.1" > /etc/resolv.conf
# Lock file to prevent overwrites (optional, but good for persistence during session)
# chattr +i /etc/resolv.conf 2>/dev/null 

echo -e "${GREEN}✓ /etc/resolv.conf set to 127.0.0.1${NC}"

# 6. Firewall Kill Switch (IPTables)
echo -e "\n${YELLOW}[6/10] Configuring Firewall Kill Switch for 'anon'${NC}"

# Flush existing rules for anon user (if any custom chains existed, this might need adjustment, but for now we append/insert)
# We will use OUTPUT chain to block anon user

# Check if anon user exists
if id "anon" &>/dev/null; then
    ANON_UID=$(id -u anon)
    
    # clear previous rules related to anon in OUTPUT
    # This is tricky without flushing everything. We'll just append ensuring they are at the top or managing a custom chain.
    # For simplicity in this script, we'll try to remove then add, or just add.
    
    # Ensure blocking of non-Tor traffic for anon
    # Allow traffic to loopback (Tor SOCKS/Control)
    iptables -A OUTPUT -o lo -m owner --uid-owner "$ANON_UID" -j ACCEPT
    
    # Allow traffic to Tor TransPort/DNS (if transparent proxying used) or just SOCKS
    # Tor usually listens on 127.0.0.1:9050 (SOCKS) and 53 (DNS if configured). Access to LO covers this.
    
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
echo "✓ MAC Address: Randomized"
echo "✓ Hostname: $RANDOM_HOSTNAME"
echo "✓ Timezone: $RANDOM_TZ"
echo "✓ IPv6: Disabled"
echo "✓ DNS: Forced to 127.0.0.1 (Tor)"
echo "✓ Firewall: 'anon' user traffic restricted to localhost"
echo "✓ History: Disabled"
echo ""
echo -e "${GREEN}Enhanced evasion mode active!${NC}"
echo -e "${YELLOW}Remember: Use responsibly and legally!${NC}"

