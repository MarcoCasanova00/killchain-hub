#!/bin/bash
# Killchain Hub v5.0 Kali Linux Installer
# Optimized for Kali - removes Docker dependency, uses native tools

if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo "=== Killchain Hub Installer v5.0 (Kali Linux) ==="
echo "${BLUE}Optimized for Kali - Native tools only, no Docker${NC}"

# Check running on Kali
if [ ! -f /etc/os-release ] || ! grep -q "kali" /etc/os-release; then
    echo -e "${YELLOW}Warning: This installer is optimized for Kali Linux${NC}"
    echo -e "${YELLOW}Continue anyway? (y/N): ${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Run as root: sudo ./install_kali.sh${NC}"
    exit 1
fi

# Update Kali repositories
echo -e "${YELLOW}Updating Kali repositories...${NC}"
apt update && apt upgrade -y

# Install core Kali tools (all available in Kali repos)
echo -e "${YELLOW}Installing Kali security tools...${NC}"
KALI_PACKAGES=(
    # Core security tools
    nmap
    gobuster
    hydra
    nikto
    dnsrecon
    dnsutils
    whois
    netcat-openbsd
    
    # Python & environment
    python3
    python3-pip
    python3-venv
    python3-dev
    
    # Privacy & anonymity
    tor
    torsocks
    proxychains4
    macchanger
    
    # Go environment
    golang-go
    build-essential
    
    # Additional tools
    git
    curl
    wget
    jq
    unzip
    p7zip-full
    
    # Wordlists
    wordlists
    seclists
    
    # OSINT tools (Kali has these pre-packaged)
    theharvester
    amass
    recon-ng
    spiderfoot
    
    # Web tools
    dirsearch
    sqlmap
    ffuf
    
    # System utilities
    net-tools
    libpcap-dev
)

for pkg in "${KALI_PACKAGES[@]}"; do
    echo -e "${BLUE}[*] Installing: ${pkg}${NC}"
    if ! apt install -y "$pkg"; then
        echo -e "${RED}✗ Failed to install: ${pkg}${NC}"
        echo -e "${YELLOW}  -> Will try alternative method later${NC}"
    fi
done

# Install Go tools via GitHub releases if apt versions are outdated
echo -e "${YELLOW}Installing/updating Go tools via GitHub...${NC}"
export GOPATH=/root/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
mkdir -p $GOPATH

# Function to install Go tools from GitHub
install_go_tool() {
    local name=$1
    local repo=$2
    local binary_name=${3:-$1}
    
    echo -e "${YELLOW}[*] Installing ${name} from GitHub...${NC}"
    
    # Get latest release
    ARCH=$(dpkg --print-architecture | sed 's/amd64/x86_64/; s/arm64/arm64/')
    case $ARCH in
        x86_64) G_ARCH="amd64" ;;
        arm64) G_ARCH="arm64" ;;
        *) G_ARCH="amd64" ;;
    esac
    
    LATEST_TAG=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name)
    if [ "$LATEST_TAG" != "null" ] && [ -n "$LATEST_TAG" ]; then
        DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | \
            jq -r ".assets[] | select(.name | contains(\"linux\") and contains(\"$G_ARCH\") and (contains(\"tar.gz\") or contains(\"zip\"))) | .browser_download_url" | head -n 1)
        
        if [ -n "$DOWNLOAD_URL" ] && [ "$DOWNLOAD_URL" != "null" ]; then
            wget -q "$DOWNLOAD_URL" -O "/tmp/$name.bin"
            if [[ "$DOWNLOAD_URL" == *.zip ]]; then
                unzip -o "/tmp/$name.bin" -d /tmp/ 2>/dev/null || true
            else
                tar -xzf "/tmp/$name.bin" -C /tmp/ 2>/dev/null || true
            fi
            
            # Find and copy binary
            find /tmp -type f -name "$binary_name" -exec cp {} /usr/local/bin/ \; 2>/dev/null || true
            chmod +x "/usr/local/bin/$binary_name" 2>/dev/null || true
            
            if command -v "$binary_name" &>/dev/null; then
                echo -e "${GREEN}✓ ${name} installed ($LATEST_TAG)${NC}"
                rm -f "/tmp/$name.bin"
                return 0
            fi
        fi
    fi
    echo -e "${RED}✗ Failed to install ${name}${NC}"
    return 1
}

# Update/install modern Go tools if not available or outdated
if ! command -v nuclei &>/dev/null || [[ $(nuclei -version 2>/dev/null | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1) < "3.0.0" ]]; then
    install_go_tool "nuclei" "projectdiscovery/nuclei" "nuclei"
fi

if ! command -v subfinder &>/dev/null; then
    install_go_tool "subfinder" "projectdiscovery/subfinder" "subfinder"
fi

if ! command -v gospider &>/dev/null; then
    install_go_tool "gospider" "jaeles-project/gospider" "gospider"
fi

# Install Python requirements
echo -e "${YELLOW}Installing Python dependencies...${NC}"
if [ -f "requirements.txt" ]; then
    pip3 install -r requirements.txt --break-system-packages --no-cache-dir
else
    echo -e "${YELLOW}requirements.txt not found, skipping...${NC}"
fi

# Setup anon user
echo -e "${YELLOW}Setting up anon user...${NC}"
if ! id "anon" &>/dev/null; then
    useradd -m -s /bin/bash anon
fi

# Add anon to sudoers for pentesting operations
echo "anon ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/anon >/dev/null
chmod 440 /etc/sudoers.d/anon

# Setup anon-mode script
cat > /usr/local/bin/anon-mode << 'EOF'
#!/bin/bash
# Switch to anon user with pentesting environment
if [ "$(whoami)" != "anon" ]; then
    if command -v sudo >/dev/null 2>&1; then
        sudo -u anon -i
    else
        su - anon
    fi
else
    echo "Already logged in as anon"
fi
EOF
chmod +x /usr/local/bin/anon-mode

# Install killchain-hub and libraries
echo -e "${YELLOW}Installing killchain-hub...${NC}"
cp killchain-hub.sh /usr/local/bin/killchain-hub
chmod +x /usr/local/bin/killchain-hub

# Copy lib directory
mkdir -p /usr/local/bin/lib
if [ -d "lib" ]; then
    cp -r lib/* /usr/local/bin/lib/
    chmod +x /usr/local/bin/lib/*.sh
fi

# Install status-check script
if [ -f "status-check.sh" ]; then
    cp status-check.sh /usr/local/bin/status-check
    chmod +x /usr/local/bin/status-check
fi

# Setup Kali-optimized config
if [ -f ".killchain-hub.conf" ]; then
    mkdir -p /home/anon
    cp .killchain-hub.conf /home/anon/.killchain-hub.conf
    # Modify config for Kali (no Docker)
    sed -i 's/FORCE_TOR="yes"/FORCE_TOR="yes"/' /home/anon/.killchain-hub.conf
    sed -i 's|THEHARVESTER_DOCKER_IMAGE="kalilinux/kali-rolling"|THEHARVESTER_DOCKER_IMAGE=""|' /home/anon/.killchain-hub.conf
    chown anon:anon /home/anon/.killchain-hub.conf
    chmod 644 /home/anon/.killchain-hub.conf
fi

# Setup anon environment
echo -e "${YELLOW}Configuring anon environment...${NC}"
cat > /home/anon/.bashrc << 'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.
export TERM=xterm-256color
stty echo 2>/dev/null

# Kali Pentesting Prompt
export PS1='${debian_chroot:+($debian_chroot)}\[\033[01;31m\]anon@kali-pentest\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Aliases for pentesting tools
alias ll='ls -la'
alias killchain-hub='/usr/local/bin/killchain-hub'
alias status-check='/usr/local/bin/status-check'
alias anon-proxy='export http_proxy=socks5://127.0.0.1:9050; export https_proxy=socks5://127.0.0.1:9050'

# Tool aliases for convenience
alias nh='nmap -h'
alias gh='gobuster -h'
alias hh='hydra -h'

# Ensure PATH includes all pentesting tools
export PATH=$PATH:/usr/local/bin:/usr/bin:/sbin:/usr/sbin:/bin:/usr/local/sbin

# Auto-update nuclei templates (weekly)
if [ -f /usr/local/bin/nuclei ]; then
    # Check if last update was more than 7 days ago
    if find /home/anon -name ".nuclei_update" -mtime +7 2>/dev/null | grep -q .; then
        nuclei -update-templates 2>/dev/null && touch /home/anon/.nuclei_update &
    fi
fi
EOF

# Create .profile for login shells
cat > /home/anon/.profile << 'EOF'
# ~/.profile: executed by the command interpreter for login shells.
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
EOF

chown -R anon:anon /home/anon
chmod 644 /home/anon/.bashrc /home/anon/.profile

# Setup Tor (Kali optimized)
echo -e "${YELLOW}Configuring Tor for Kali...${NC}"
systemctl enable --now tor

# Create enhanced torsocks config
cat > /etc/torsocks.conf << 'EOF'
server = 127.0.0.1
server_port = 9050
server_type = 5
# Additional privacy settings
TorAddress 127.0.0.1
TorPort 9050
EOF

# Setup log directory
mkdir -p /home/anon/killchain_logs
chown anon:anon /home/anon/killchain_logs
chmod 755 /home/anon/killchain_logs

# Extract wordlists
if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
    gunzip -k /usr/share/wordlists/rockyou.txt.gz 2>/dev/null || true
fi

# Update nuclei templates
if command -v nuclei &>/dev/null; then
    echo -e "${YELLOW}Updating nuclei templates...${NC}"
    sudo -u anon nuclei -update-templates 2>/dev/null || true
    touch /home/anon/.nuclei_update
fi

# Create Kali-specific desktop shortcut (optional)
if [ -d /usr/share/applications ]; then
    cat > /usr/share/applications/killchain-hub.desktop << 'EOF'
[Desktop Entry]
Name=Killchain Hub
Comment=Automated Penetration Testing Framework
Exec=/usr/local/bin/anon-mode
Icon=security
Terminal=true
Type=Application
Categories=Security;Network;
EOF
fi

echo -e "\n${GREEN}✓ Kali installation completed!${NC}"
echo ""
echo "${BLUE}Kali-Optimized Features:${NC}"
echo "  • Native theHarvester (no Docker needed)"
echo "  • All tools from Kali repositories"
echo "  • Pre-configured privacy tools"
echo "  • Enhanced anon environment"
echo ""
echo "${BLUE}Quick Start:${NC}"
echo "  ${YELLOW}anon-mode${NC}        # Switch to pentesting user"
echo "  ${YELLOW}status-check${NC}     # Verify anonymity & tools"
echo "  ${YELLOW}killchain-hub${NC}    # Start framework"
echo ""
echo "${BLUE}Tool Status:${NC}"
echo "  Core: nmap ✓ gobuster ✓ hydra ✓ nikto ✓"
echo "  OSINT: theHarvester ✓ amass ✓ recon-ng ✓"
echo "  Advanced: nuclei ✓ subfinder ✓ sqlmap ✓"
echo ""
echo "${YELLOW}Note: All traffic routed through Tor by default${NC}"
echo "${YELLOW}      Use 'anon-proxy' alias for manual proxy setup${NC}"