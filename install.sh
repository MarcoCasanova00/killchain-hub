#!/bin/bash
# Installazione Killchain Hub v5.0

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

# Install core dependencies
echo -e "${YELLOW}Installazione dipendenze core...${NC}"
apt install -y \
    docker.io \
    torsocks \
    tor \
    nmap \
    gobuster \
    hydra \
    nikto \
    dnsrecon \
    git \
    curl \
    wget \
    dnsutils \
    netcat-openbsd \
    python3 \
    python3-pip \
    python3-venv \
    jq \
    unzip \
    wordlists \
    golang-go \
    build-essential \
    macchanger \
    net-tools

# Install Python requirements
echo -e "${YELLOW}Installazione dipendenze Python...${NC}"
if [ -f "requirements.txt" ]; then
    pip3 install -r requirements.txt --break-system-packages --no-cache-dir
else
    echo -e "${YELLOW}requirements.txt non trovato, skip...${NC}"
fi

# Install dirsearch via pip (if not in requirements.txt)
pip3 install dirsearch --break-system-packages --no-cache-dir 2>/dev/null || true

# Install Go-based tools
echo -e "${YELLOW}Installazione tool Go...${NC}"

# Setup Go environment
export GOPATH=/root/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
mkdir -p $GOPATH

# Install subfinder
if ! command -v subfinder &>/dev/null; then
    echo -e "${YELLOW}Installazione subfinder...${NC}"
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    cp $GOPATH/bin/subfinder /usr/local/bin/ 2>/dev/null || true
fi

# Install nuclei
if ! command -v nuclei &>/dev/null; then
    echo -e "${YELLOW}Installazione nuclei...${NC}"
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
    cp $GOPATH/bin/nuclei /usr/local/bin/ 2>/dev/null || true
fi

# Install ffuf
if ! command -v ffuf &>/dev/null; then
    echo -e "${YELLOW}Installazione ffuf...${NC}"
    go install github.com/ffuf/ffuf/v2@latest
    cp $GOPATH/bin/ffuf /usr/local/bin/ 2>/dev/null || true
fi

# Install amass
if ! command -v amass &>/dev/null; then
    echo -e "${YELLOW}Installazione amass...${NC}"
    go install -v github.com/owasp-amass/amass/v4/...@master
    cp $GOPATH/bin/amass /usr/local/bin/ 2>/dev/null || true
fi

# Install gospider
if ! command -v gospider &>/dev/null; then
    echo -e "${YELLOW}Installazione gospider...${NC}"
    go install github.com/jaeles-project/gospider@latest
    cp $GOPATH/bin/gospider /usr/local/bin/ 2>/dev/null || true
fi

# Setup Docker
echo -e "${YELLOW}Configurazione Docker...${NC}"
if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now docker
else
    echo -e "${YELLOW}Systemd non presente. Avvio manuale Docker richiesto (se non già attivo).${NC}"
    if command -v service >/dev/null 2>&1; then
        service docker start || echo -e "${RED}Impossibile avviare docker service${NC}"
    fi
fi

# Add user to docker group if docker is installed
if command -v docker >/dev/null 2>&1; then
    usermod -aG docker $(logname 2>/dev/null || echo "$SUDO_USER")
fi

# Setup anon user
echo -e "${YELLOW}Setup user anon...${NC}"
useradd -m -s /bin/bash anon 2>/dev/null || true
if command -v sudo >/dev/null 2>&1; then
    usermod -aG sudo anon
    echo "anon ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/anon
    chmod 440 /etc/sudoers.d/anon
fi
# Add to docker group only if docker group exists
if getent group docker >/dev/null 2>&1; then
    usermod -aG docker anon
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