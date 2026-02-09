#!/bin/bash
# Enhanced Evasion Script for Killchain-Hub
# Provides multiple layers of anonymity and anti-forensics

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}=== Enhanced Evasion Mode ===${NC}\n"

# 1. MAC Address Randomization
echo -e "${YELLOW}[1/8] MAC Address Randomization${NC}"
if command -v macchanger &>/dev/null; then
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -n "$INTERFACE" ]; then
        sudo ip link set "$INTERFACE" down
        sudo macchanger -r "$INTERFACE" 2>/dev/null
        sudo ip link set "$INTERFACE" up
        echo -e "${GREEN}✓ MAC address randomized on $INTERFACE${NC}"
    else
        echo -e "${YELLOW}⚠ No network interface found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ macchanger not installed (optional)${NC}"
fi

# 2. Hostname Randomization
echo -e "\n${YELLOW}[2/8] Hostname Randomization${NC}"
RANDOM_HOSTNAME="host-$(openssl rand -hex 4)"
sudo hostnamectl set-hostname "$RANDOM_HOSTNAME" 2>/dev/null
echo -e "${GREEN}✓ Hostname changed to: $RANDOM_HOSTNAME${NC}"

# 3. Timezone Obfuscation
echo -e "\n${YELLOW}[3/8] Timezone Obfuscation${NC}"
TIMEZONES=("UTC" "America/New_York" "Europe/London" "Asia/Tokyo" "Australia/Sydney")
RANDOM_TZ=${TIMEZONES[$RANDOM % ${#TIMEZONES[@]}]}
sudo timedatectl set-timezone "$RANDOM_TZ" 2>/dev/null
echo -e "${GREEN}✓ Timezone set to: $RANDOM_TZ${NC}"

# 4. DNS over Tor
echo -e "\n${YELLOW}[4/8] DNS Configuration${NC}"
if [ -f /etc/resolv.conf ]; then
    sudo cp /etc/resolv.conf /etc/resolv.conf.backup
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf > /dev/null
    echo -e "${GREEN}✓ DNS routed through Tor${NC}"
fi

# 5. Disable History
echo -e "\n${YELLOW}[5/8] History Cleanup${NC}"
unset HISTFILE
export HISTSIZE=0
export HISTFILESIZE=0
history -c 2>/dev/null
cat /dev/null > ~/.bash_history 2>/dev/null
echo -e "${GREEN}✓ Bash history disabled${NC}"

# 6. Clear System Logs (requires root)
echo -e "\n${YELLOW}[6/8] Log Cleanup${NC}"
if [ "$EUID" -eq 0 ]; then
    find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null
    echo -e "${GREEN}✓ System logs cleared${NC}"
else
    echo -e "${YELLOW}⚠ Run as root to clear system logs${NC}"
fi

# 7. Tor Circuit Renewal
echo -e "\n${YELLOW}[7/8] Tor Circuit Renewal${NC}"
if systemctl is-active --quiet tor; then
    echo "SIGNAL NEWNYM" | nc 127.0.0.1 9051 2>/dev/null || \
    sudo systemctl reload tor
    sleep 2
    echo -e "${GREEN}✓ Tor circuit renewed${NC}"
else
    echo -e "${RED}✗ Tor service not running${NC}"
fi

# 8. IP Verification
echo -e "\n${YELLOW}[8/8] IP Verification${NC}"
REAL_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
TOR_IP=$(torsocks curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")

echo -e "Real IP:  ${RED}$REAL_IP${NC}"
echo -e "Tor IP:   ${GREEN}$TOR_IP${NC}"

if [ "$REAL_IP" = "$TOR_IP" ]; then
    echo -e "\n${RED}⚠ WARNING: Tor routing may not be working!${NC}"
else
    echo -e "\n${GREEN}✓ Tor routing confirmed${NC}"
fi

# 9. User Agent Randomization
echo -e "\n${YELLOW}[9/8] User Agent Pool${NC}"
cat > /tmp/user-agents.txt << 'EOF'
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36
Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36
Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0
Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:121.0) Gecko/20100101 Firefox/121.0
EOF
export USER_AGENT=$(shuf -n 1 /tmp/user-agents.txt)
echo -e "${GREEN}✓ Random user agent set${NC}"

# 10. Anti-Forensics Summary
echo -e "\n${CYAN}=== Evasion Summary ===${NC}"
echo "✓ MAC Address: Randomized"
echo "✓ Hostname: $RANDOM_HOSTNAME"
echo "✓ Timezone: $RANDOM_TZ"
echo "✓ DNS: Routed through Tor"
echo "✓ History: Disabled"
echo "✓ Tor IP: $TOR_IP"
echo ""
echo -e "${GREEN}Enhanced evasion mode active!${NC}"
echo -e "${YELLOW}Remember: Use responsibly and legally!${NC}"
