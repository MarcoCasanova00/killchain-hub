#!/bin/bash
# Anonymity & Security Pre-Flight Check
# Comprehensive verification of all evasion measures

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

PASS=0
FAIL=0
WARN=0

# Set path for sysctl (Debian/Ubuntu fix)
SYSCTL="/sbin/sysctl"
if ! [ -x "$SYSCTL" ]; then SYSCTL="sysctl"; fi

# Header
clear
echo -e "${CYAN}"
echo "     \\ /"
echo "     oVo"
echo " \\___XXX___/"
echo "  __XXXXX__"
echo " /__XXXXX__\\"
echo " /   XXX   \\"
echo "      V"
echo -e "${NC}"
echo -e "${GREEN}=== ANONYMITY PRE-FLIGHT CHECK ===${NC}"
echo -e "${YELLOW}Verifying all evasion measures...${NC}\n"

# Function to check and report
check_status() {
    local name="$1"
    local status="$2"
    local details="$3"
    
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $name: ${GREEN}$details${NC}"
        ((PASS++))
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}✗${NC} $name: ${RED}$details${NC}"
        ((FAIL++))
    else
        echo -e "${YELLOW}⚠${NC} $name: ${YELLOW}$details${NC}"
        ((WARN++))
    fi
}

# Generic installer for missing tools (Debian/Ubuntu/Kali/Parrot + Arch/Manjaro)
install_tool_generic() {
    local tool="$1"

    # Detect package manager
    if command -v apt-get >/dev/null 2>&1; then
        echo -e "${YELLOW}Attempting to install '$tool' via apt-get...${NC}"
        if ! sudo apt-get install -y "$tool"; then
            echo -e "${RED}apt-get failed to install '$tool'.${NC}"
            # Give a better hint for common security tools that are only in some repos
            if ! apt-cache show "$tool" >/dev/null 2>&1; then
                echo -e "${YELLOW}Hint:${NC} package '${tool}' was not found in your enabled APT repositories."
                echo -e "      On vanilla Debian you may need to enable 'testing' or a security repo (e.g. Kali) to install some tools (e.g. nikto, spiderfoot, recon-ng)."
            fi
            return 1
        fi
    elif command -v pacman >/dev/null 2>&1; then
        echo -e "${YELLOW}Attempting to install '$tool' via pacman/yay...${NC}"
        if command -v yay >/dev/null 2>&1; then
            if ! yay -S --needed --noconfirm "$tool"; then
                echo -e "${RED}yay failed to install '$tool'.${NC}"
                return 1
            fi
        else
            if ! sudo pacman -S --needed --noconfirm "$tool"; then
                echo -e "${RED}pacman failed to install '$tool'.${NC}"
                return 1
            fi
        fi
    else
        echo -e "${RED}No supported package manager (apt/pacman) found for automatic install of '$tool'.${NC}"
        return 1
    fi

    # Final verification
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ '$tool' installed and available in PATH.${NC}"
        return 0
    else
        echo -e "${RED}Install command completed but '$tool' is still not in PATH.${NC}"
        return 1
    fi
}

# Wrapper that prompts the user and calls the generic installer
handle_missing_tool() {
    local tool="$1"
    local required_level="$2"  # "required" or "optional"

    local status_label="FAIL"
    local requirement_text="Required"
    if [ "$required_level" = "optional" ]; then
        status_label="WARN"
        requirement_text="Optional"
    fi

    echo -e "${YELLOW}$requirement_text tool '$tool' is not installed.${NC}"
    echo -ne "  → Attempt to install it now? [y/N]: "
    read ANSWER

    if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
        check_status "$tool" "$status_label" "Not installed (user skipped auto-install)"
        return
    fi

    if install_tool_generic "$tool"; then
        check_status "$tool" "PASS" "$(command -v $tool)"
    else
        local msg="Automatic installation failed"
        if [ "$tool" = "nikto" ]; then
            msg="$msg (on Debian you may need to enable 'testing' or a security repo for nikto)."
        fi
        check_status "$tool" "$status_label" "$msg"
    fi
}

echo -e "${BLUE}[1] USER & ENVIRONMENT${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check current user
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" = "anon" ]; then
    check_status "User Identity" "PASS" "Running as 'anon' (isolated)"
else
    check_status "User Identity" "FAIL" "Running as '$CURRENT_USER' (should be 'anon')"
fi

# Check hostname
HOSTNAME=$(hostname)
if [[ "$HOSTNAME" =~ ^(pentest-lab|host-[a-f0-9]+)$ ]]; then
    check_status "Hostname" "PASS" "$HOSTNAME (randomized)"
else
    check_status "Hostname" "WARN" "$HOSTNAME (not randomized)"
fi

# Check bash history
if [ -z "$HISTFILE" ] || [ "$HISTSIZE" = "0" ]; then
    check_status "Bash History" "PASS" "Disabled"
else
    check_status "Bash History" "WARN" "Enabled (may log commands)"
fi

echo ""
echo -e "${BLUE}[2] NETWORK ANONYMITY${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check Tor service
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet tor; then
    check_status "Tor Service" "PASS" "Running"
elif command -v service >/dev/null 2>&1 && service tor status >/dev/null 2>&1; then
    check_status "Tor Service" "PASS" "Running (init.d)"
elif pgrep -x tor >/dev/null 2>&1; then
    check_status "Tor Service" "PASS" "Running (process found)"
else
    check_status "Tor Service" "FAIL" "Not running"
fi

# Check Tor port
if sudo ss -tlnp 2>/dev/null | grep -q 9050; then
    check_status "Tor SOCKS Port" "PASS" "9050 listening"
else
    check_status "Tor SOCKS Port" "FAIL" "9050 not listening"
fi

# IP Leak Test
echo -ne "${CYAN}  → Testing IP leak...${NC} "
REAL_IP=$(timeout 5 curl -s ifconfig.me 2>/dev/null || echo "N/A")
TOR_IP=$(timeout 5 torsocks curl -s ifconfig.me 2>/dev/null || echo "N/A")

if [ "$REAL_IP" != "N/A" ] && [ "$TOR_IP" != "N/A" ]; then
    if [ "$REAL_IP" = "$TOR_IP" ]; then
        echo ""
        check_status "IP Anonymization" "FAIL" "Real IP = Tor IP ($REAL_IP)"
    else
        echo ""
        check_status "IP Anonymization" "PASS" "Real: $REAL_IP → Tor: $TOR_IP"
    fi
else
    echo ""
    check_status "IP Anonymization" "WARN" "Could not verify (network issue)"
fi

# DNS Leak Test
DNS_SERVER=$(grep nameserver /etc/resolv.conf 2>/dev/null | head -n1 | awk '{print $2}')
if [ "$DNS_SERVER" = "127.0.0.1" ]; then
    check_status "DNS Configuration" "PASS" "Routed through localhost (Tor)"
else
    check_status "DNS Configuration" "FAIL" "Using $DNS_SERVER (DNS Leak Risk!)"
fi

# IPv6 Leak Test
IPV6_DISABLE=$($SYSCTL net.ipv6.conf.all.disable_ipv6 2>/dev/null | awk '{print $3}')
if [ "$IPV6_DISABLE" = "1" ]; then
    check_status "IPv6 Status" "PASS" "Disabled (No IPv6 Leaks)"
else
    check_status "IPv6 Status" "FAIL" "Enabled (IPv6 Leak Vector - Tor is IPv4 only!)"
fi

# Firewall Kill Switch Test
# Check if there are OUTPUT rules for anon user
if sudo iptables -L OUTPUT -n -v 2>/dev/null | grep -q "owner UID match"; then
    check_status "Firewall Kill Switch" "PASS" "Rules detected for user restriction"
else
    check_status "Firewall Kill Switch" "WARN" "No specific user restriction rules found"
fi

# Check for WebRTC leaks (if browser tools available)
if command -v curl &>/dev/null; then
    WEBRTC_TEST=$(timeout 3 curl -s "https://browserleaks.com/webrtc" 2>/dev/null | grep -o "Local IP" | head -n1)
    if [ -z "$WEBRTC_TEST" ]; then
        check_status "WebRTC Leak" "PASS" "No local IP detected"
    else
        check_status "WebRTC Leak" "WARN" "Potential WebRTC leak (use browser extensions)"
    fi
fi

echo ""
echo -e "${BLUE}[3] PROXY CONFIGURATION${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check torsocks
if command -v torsocks &>/dev/null; then
    check_status "Torsocks" "PASS" "Installed"
else
    check_status "Torsocks" "FAIL" "Not installed"
fi

# Check proxychains (alternative)
if command -v proxychains4 &>/dev/null || command -v proxychains &>/dev/null; then
    check_status "Proxychains" "PASS" "Available as fallback"
else
    check_status "Proxychains" "WARN" "Not installed (optional)"
fi

echo ""
echo -e "${BLUE}[4] TOOL AVAILABILITY${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Core tools
TOOLS=("nmap" "gobuster" "hydra" "nikto" "dnsrecon" "docker")
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        check_status "$tool" "PASS" "$(command -v $tool)"
    else
        handle_missing_tool "$tool" "required"
    fi
done

# Advanced tools (Recon & Web)
ADV_TOOLS=("subfinder" "nuclei" "ffuf" "dirsearch" "amass" "spiderfoot" "recon-ng")
for tool in "${ADV_TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        check_status "$tool" "PASS" "$(command -v $tool)"
    else
        handle_missing_tool "$tool" "optional"
    fi
done

echo ""
echo -e "${BLUE}[5] DOCKER & CONTAINERS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Docker service
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet docker; then
    check_status "Docker Service" "PASS" "Running"
elif command -v service >/dev/null 2>&1 && service docker status >/dev/null 2>&1; then
    check_status "Docker Service" "PASS" "Running (init.d)"
elif pgrep -x dockerd >/dev/null 2>&1; then
    check_status "Docker Service" "PASS" "Running (dockerd found)"
else
    check_status "Docker Service" "FAIL" "Not running"
fi

# Docker permissions
if groups | grep -q docker; then
    check_status "Docker Permissions" "PASS" "User in docker group"
else
    check_status "Docker Permissions" "WARN" "User not in docker group"
fi

# Kali image
if docker images | grep -q kalilinux/kali-rolling; then
    check_status "Kali Image" "PASS" "Cached locally"
else
    check_status "Kali Image" "WARN" "Not cached (will download on first use)"
fi

echo ""
echo -e "${BLUE}[6] LOGGING & FORENSICS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Log directory
if [ -d "/home/anon/killchain_logs" ]; then
    LOG_PERMS=$(stat -c "%a" /home/anon/killchain_logs 2>/dev/null)
    check_status "Log Directory" "PASS" "/home/anon/killchain_logs (perms: $LOG_PERMS)"
else
    check_status "Log Directory" "FAIL" "Not created"
fi

# Logger library
if [ -f "/usr/local/bin/lib/logger.sh" ] || [ -f "./lib/logger.sh" ]; then
    check_status "Logger Library" "PASS" "Available"
else
    check_status "Logger Library" "FAIL" "Not found"
fi

# Evasion script
if [ -f "/usr/local/bin/lib/evasion.sh" ] || [ -f "./lib/evasion.sh" ]; then
    check_status "Evasion Script" "PASS" "Available"
else
    check_status "Evasion Script" "WARN" "Not found (basic evasion only)"
fi

echo ""
echo -e "${BLUE}[7] SYSTEM HARDENING${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# MAC address randomization
if command -v macchanger &>/dev/null; then
    check_status "MAC Changer" "PASS" "Installed"
else
    check_status "MAC Changer" "WARN" "Not installed (optional)"
fi

# Check if running in VM
if systemd-detect-virt &>/dev/null; then
    VIRT_TYPE=$(systemd-detect-virt)
    check_status "Virtualization" "PASS" "Running in $VIRT_TYPE (isolated)"
else
    check_status "Virtualization" "WARN" "Not detected (bare metal?)"
fi

# Firewall status
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(sudo ufw status 2>/dev/null | head -n1)
    if [[ "$UFW_STATUS" =~ "active" ]]; then
        check_status "Firewall" "PASS" "UFW active"
    else
        check_status "Firewall" "WARN" "UFW inactive"
    fi
else
    check_status "Firewall" "WARN" "UFW not installed"
fi

echo ""
echo -e "${BLUE}[8] GEOLOCATION & FINGERPRINTING${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Timezone check
CURRENT_TZ=$(timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}')
if [ -n "$CURRENT_TZ" ]; then
    check_status "Timezone" "PASS" "$CURRENT_TZ"
else
    check_status "Timezone" "WARN" "Could not determine"
fi

# Tor exit node location (if possible)
if [ "$TOR_IP" != "N/A" ]; then
    TOR_COUNTRY=$(timeout 3 curl -s "http://ip-api.com/json/$TOR_IP" 2>/dev/null | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$TOR_COUNTRY" ]; then
        check_status "Tor Exit Node" "PASS" "$TOR_COUNTRY"
    else
        check_status "Tor Exit Node" "WARN" "Could not determine location"
    fi
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}PASSED: $PASS${NC} | ${YELLOW}WARNINGS: $WARN${NC} | ${RED}FAILED: $FAIL${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Overall status
if [ $FAIL -eq 0 ]; then
    if [ $WARN -eq 0 ]; then
        echo -e "\n${GREEN}✓ ALL SYSTEMS OPERATIONAL${NC}"
        echo -e "${GREEN}You are ready to proceed with anonymized operations.${NC}\n"
        exit 0
    else
        echo -e "\n${YELLOW}⚠ OPERATIONAL WITH WARNINGS${NC}"
        echo -e "${YELLOW}Review warnings above. Most operations should work.${NC}\n"
        exit 0
    fi
else
    echo -e "\n${RED}✗ CRITICAL ISSUES DETECTED${NC}"
    echo -e "${RED}Fix failed checks before proceeding!${NC}\n"
    
    # Provide quick fixes
    echo -e "${CYAN}Quick Fixes:${NC}"
    if [ "$CURRENT_USER" != "anon" ]; then
        echo "  → Run: anon-mode"
    fi
    
    # DNS fix - check if DNS_SERVER variable exists and is not 127.0.0.1
    if [ -n "$DNS_SERVER" ] && [ "$DNS_SERVER" != "127.0.0.1" ]; then
        echo "  → DNS Leak Detected! Run: killchain-hub → Option 5 → Option 2 (Apply Evasion)"
    fi
    
    # tor fix
    TOR_START="sudo tor &"
    if command -v systemctl >/dev/null 2>&1; then TOR_START="sudo systemctl start tor"
    elif command -v service >/dev/null 2>&1; then TOR_START="sudo service tor start"; fi
    
    # docker fix
    DOCKER_START="sudo dockerd &"
    if command -v systemctl >/dev/null 2>&1; then DOCKER_START="sudo systemctl start docker"
    elif command -v service >/dev/null 2>&1; then DOCKER_START="sudo service docker start"; fi

    if ! pgrep -x tor >/dev/null 2>&1; then
        echo "  → Run: $TOR_START"
    fi
    if ! pgrep -x dockerd >/dev/null 2>&1 && ! pgrep -x docker >/dev/null 2>&1; then
        echo "  → Run: $DOCKER_START"
    fi
    echo ""
    exit 1
fi
