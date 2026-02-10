#!/bin/bash
# Installazione Killchain Hub v5.0

if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo "=== Killchain Hub Installer v5.0 ==="

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Esegui come root: sudo ./install.sh${NC}"
    exit 1
fi

# Update system
echo -e "${YELLOW}Aggiornamento sistema...${NC}"
apt update && apt upgrade -y

# Remove legacy/conflicting docker package
echo -e "${YELLOW}Rimozione pacchetti docker obsoleti/conflittuali...${NC}"
apt purge -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Install core dependencies (per-package to better handle errors/missing repos)
echo -e "${YELLOW}Installazione dipendenze core...${NC}"
CORE_PACKAGES=(
    docker.io
    torsocks
    tor
    nmap
    hydra
    nikto
    dnsrecon
    git
    curl
    wget
    dnsutils
    netcat-openbsd
    python3
    python3-pip
    python3-venv
    jq
    unzip
    wordlists
    golang-go
    build-essential
    macchanger
    net-tools
    p7zip-full
    libpcap-dev
)

for pkg in "${CORE_PACKAGES[@]}"; do
    echo -e "${YELLOW}[*] Installing package: ${pkg}${NC}"
    if ! apt install -y "$pkg"; then
        echo -e "${RED}✗ Failed to install package: ${pkg}${NC}"
        if [ "$pkg" = "nikto" ]; then
            echo -e "${YELLOW}Hint:${NC} on some pure Debian setups 'nikto' may only be available in testing/offensive-security repos."
            echo -e "      Consider enabling Debian 'testing' or a Kali-style security repo, or install nikto from source (GitHub) if you need it."
        fi
    fi
done

# Improved Go Installation
GO_VERSION="1.21.6"
if ! command -v go &>/dev/null || [[ $(go version | awk '{print $3}' | sed 's/go//') < "1.21.0" ]]; then
    echo -e "${YELLOW}Go is missing or outdated. Installing Go ${GO_VERSION}...${NC}"
    ARCH=$(dpkg --print-architecture)
    case $ARCH in
        amd64) GO_ARCH="amd64" ;;
        arm64) GO_ARCH="arm64" ;;
        *) GO_ARCH="amd64" ;;
    esac
    wget "https://golang.org/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -O /tmp/go.tar.gz
    rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
fi

# Install Python requirements
echo -e "${YELLOW}Installazione dipendenze Python...${NC}"
if [ -f "requirements.txt" ]; then
    pip3 install -r requirements.txt --break-system-packages --no-cache-dir
else
    echo -e "${YELLOW}requirements.txt non trovato, skip...${NC}"
fi

# Install dirsearch via pip (if not in requirements.txt)
pip3 install dirsearch --break-system-packages --no-cache-dir 2>/dev/null || true

# Setup Go environment for installer session
export GOPATH=/root/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
mkdir -p $GOPATH

# Function to install Go tools with fallback
install_go_tool() {
    local name=$1
    local repo=$2
    local binary_name=${3:-$1}
    local github_repo=$4 # e.g. "projectdiscovery/subfinder"
    
    echo -e "${YELLOW}Installazione $name...${NC}"
    
    # Try go install first
    if go install -v "$repo@latest" 2>/dev/null; then
        cp "$GOPATH/bin/$binary_name" /usr/local/bin/ 2>/dev/null || true
        if command -v "$binary_name" &>/dev/null; then
            echo -e "${GREEN}✓ $name installato via go install${NC}"
            return 0
        fi
    fi
    
    # Fallback to GitHub Releases if github_repo is provided
    if [ -n "$github_repo" ]; then
        echo -e "${YELLOW}Attenzione: go install fallito. Tento download binario da GitHub ($github_repo)...${NC}"
        ARCH=$(dpkg --print-architecture)
        case $ARCH in
            amd64) G_ARCH="amd64" ;;
            arm64) G_ARCH="arm64" ;;
            *) G_ARCH="amd64" ;;
        esac
        
        # Get latest release tag
        LATEST_TAG=$(curl -s "https://api.github.com/repos/$github_repo/releases/latest" | jq -r .tag_name)
        if [ "$LATEST_TAG" != "null" ] && [ -n "$LATEST_TAG" ]; then
            # Clean tag (remove 'v')
            VERSION=${LATEST_TAG#v}
            
            # This is a bit heuristic as naming conventions vary
            # We'll try common patterns
            DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$github_repo/releases/latest" | \
                jq -r ".assets[] | select(.name | contains(\"linux\") and contains(\"$G_ARCH\") and (contains(\"zip\") or contains(\"tar.gz\"))) | .browser_download_url" | head -n 1)
            
            if [ -n "$DOWNLOAD_URL" ] && [ "$DOWNLOAD_URL" != "null" ]; then
                wget -q "$DOWNLOAD_URL" -O "/tmp/$name.bin"
                if [[ "$DOWNLOAD_URL" == *.zip ]]; then
                    unzip -o "/tmp/$name.bin" -d /tmp/ 2>/dev/null || true
                else
                    tar -xzf "/tmp/$name.bin" -C /tmp/ 2>/dev/null || true
                fi
                
                # Find the binary in /tmp (some tools put it in a subfolder)
                find /tmp -type f -name "$binary_name" -exec cp {} /usr/local/bin/ \; 2>/dev/null || true
                chmod +x "/usr/local/bin/$binary_name" 2>/dev/null || true
                
                if command -v "$binary_name" &>/dev/null; then
                    echo -e "${GREEN}✓ $name installato via GitHub Release ($LATEST_TAG)${NC}"
                    rm -f "/tmp/$name.bin"
                    return 0
                fi
            fi
        fi
    fi
    echo -e "${RED}✗ Errore: Impossibile installare $name${NC}"
    return 1
}

# Install tools with GitHub fallbacks
install_go_tool "gobuster" "github.com/OJ/gobuster/v3" "gobuster" "OJ/gobuster"
install_go_tool "subfinder" "github.com/projectdiscovery/subfinder/v2/cmd/subfinder" "subfinder" "projectdiscovery/subfinder"
install_go_tool "nuclei" "github.com/projectdiscovery/nuclei/v3/cmd/nuclei" "nuclei" "projectdiscovery/nuclei"
install_go_tool "ffuf" "github.com/ffuf/ffuf/v2" "ffuf" "ffuf/ffuf"
install_go_tool "amass" "github.com/owasp-amass/amass/v4/..." "amass" "owasp-amass/amass"
install_go_tool "gospider" "github.com/jaeles-project/gospider" "gospider" "jaeles-project/gospider"

# Setup Docker
echo -e "${YELLOW}Configurazione Docker...${NC}"
if command -v systemctl >/dev/null 2>&1; then
    silent sudo systemctl enable --now docker
else
    echo -e "${YELLOW}Systemd non presente. Avvio manuale Docker richiesto (se non già attivo).${NC}"
    if command -v service >/dev/null 2>&1; then
        silent sudo service docker start || echo -e "${RED}Impossibile avviare docker service${NC}"
    fi
fi

# Ensure docker group exists and add users
if command -v docker >/dev/null 2>&1; then
    # Create group if missing
    if ! getent group docker >/dev/null; then
        silent sudo groupadd docker
    fi
    
    # Add Current User
    CURRENT_SUDO_USER=$(logname 2>/dev/null || echo "$SUDO_USER")
    if [ -n "$CURRENT_SUDO_USER" ]; then
        silent sudo usermod -aG docker "$CURRENT_SUDO_USER"
    fi
    
    # Add Anon User
    if id "anon" >/dev/null 2>&1; then
        silent sudo usermod -aG docker anon
    fi
fi

# Setup anon user
echo -e "${YELLOW}Setup user anon...${NC}"
silent sudo useradd -m -s /bin/bash anon 2>/dev/null || true
if command -v sudo >/dev/null 2>&1; then
    silent sudo usermod -aG sudo anon
    echo "anon ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/anon >/dev/null
    silent sudo chmod 440 /etc/sudoers.d/anon
fi

# Setup anon-mode script
cat > /usr/local/bin/anon-mode << 'EOF'
#!/bin/bash
# Switch to anon user
if [ "$(whoami)" != "anon" ]; then
    if command -v sudo >/dev/null 2>&1; then
        sudo -u anon -i
    else
        su - anon
    fi
else
    echo "Già loggato come anon"
fi
EOF
chmod +x /usr/local/bin/anon-mode

# Install killchain-hub and lib
echo -e "${YELLOW}Installazione killchain-hub...${NC}"
cp killchain-hub.sh /usr/local/bin/killchain-hub
chmod +x /usr/local/bin/killchain-hub

# Copy lib directory
mkdir -p /usr/local/bin/lib
if [ -d "lib" ]; then
    cp -r lib/* /usr/local/bin/lib/
    chmod +x /usr/local/bin/lib/*.sh
else
    echo -e "${YELLOW}lib directory non trovato, skip...${NC}"
fi

# Install status-check script
if [ -f "status-check.sh" ]; then
    cp status-check.sh /usr/local/bin/status-check
    chmod +x /usr/local/bin/status-check
    echo -e "${GREEN}✓ status-check installed${NC}"
fi

# Install default config
if [ -f ".killchain-hub.conf" ]; then
    mkdir -p /home/anon
    cp .killchain-hub.conf /home/anon/.killchain-hub.conf
    chown anon:anon /home/anon/.killchain-hub.conf
    chmod 644 /home/anon/.killchain-hub.conf
    echo -e "${GREEN}✓ Config file installed to /home/anon/.killchain-hub.conf${NC}"
fi

# Setup anon .bashrc for better visibility/UX
# Ensure .profile sources .bashrc for login shells (sudo -i)
echo -e "${YELLOW}Configurazione .profile per anon...${NC}"
cat > /home/anon/.profile << 'EOF'
# ~/.profile: executed by the command interpreter for login shells.
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
EOF
chown anon:anon /home/anon/.profile
chmod 644 /home/anon/.profile

# Setup anon .bashrc for better visibility/UX
echo -e "${YELLOW}Configurazione .bashrc per anon...${NC}"
cat > /home/anon/.bashrc << 'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.
export TERM=xterm-256color
stty echo 2>/dev/null

# Prompt settings
export PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]anon@pentest-lab\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Aliases
alias ll='ls -la'
alias killchain-hub='/usr/local/bin/killchain-hub'
alias status-check='/usr/local/bin/status-check'

# Ensure PATH
export PATH=$PATH:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin
EOF
chown anon:anon /home/anon/.bashrc
chmod 644 /home/anon/.bashrc

# Setup Tor config
echo -e "${YELLOW}Configurazione Tor...${NC}"
if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now tor
elif command -v service >/dev/null 2>&1; then
    service tor start || echo -e "${YELLOW}Tor service start failed via 'service' command.${NC}"
else
    echo -e "${YELLOW}Systemd/Service non trovati. Avvia Tor manualmente con 'tor &'.${NC}"
fi

cat > /etc/torsocks.conf << 'EOF'
server = 127.0.0.1
server_port = 9050
server_type = 5
EOF

# Create log directory
mkdir -p /home/anon/killchain_logs
chown anon:anon /home/anon/killchain_logs
chmod 755 /home/anon/killchain_logs

# Unzip wordlists
if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
    gunzip -k /usr/share/wordlists/rockyou.txt.gz 2>/dev/null || true
fi

# Cleanup
rm -f /tmp/gospider.zip 2>/dev/null

# Update nuclei templates
if command -v nuclei &>/dev/null; then
    echo -e "${YELLOW}Aggiornamento nuclei templates...${NC}"
    sudo -u anon nuclei -update-templates 2>/dev/null || true
fi

echo -e "\n${GREEN}✓ Installazione completata!${NC}"
echo ""
echo "Tool installati:"
echo "  Core: nmap, gobuster, hydra, nikto, dnsrecon, dirsearch"
echo "  Advanced: subfinder, nuclei, ffuf, amass, gospider"
echo "  Docker: theHarvester (via Kali container)"
echo ""
echo "Utilizzo:"
echo "  anon-mode      # Switcha user anon"
echo "  status-check   # Verifica anonimato e configurazione"
echo "  killchain-hub  # Avvia framework"
echo ""
echo "Test: anon-mode && status-check && killchain-hub → Fase 0 (Pre-Flight)"