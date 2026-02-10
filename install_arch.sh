#!/bin/bash
# Installazione Killchain Hub v5.0 per ARCH LINUX
# Uses pacman/yay instead of apt

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo "=== Killchain Hub Installer v5.0 (Arch Linux) ==="

# Check root not required initially for yay, but we need sudo
if [ "$EUID" -eq 0 ]; then 
    echo -e "${YELLOW}Running as root. Yay operations might need non-root user.${NC}"
fi

# Update system
echo -e "${YELLOW}Aggiornamento sistema...${NC}"
sudo pacman -Syu --noconfirm

# Install yay if missing
if ! command -v yay &> /dev/null; then
    echo -e "${YELLOW}Yay non trovato. Installazione yay...${NC}"
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
    rm -rf /tmp/yay
fi

# Install core dependencies via pacman/yay
echo -e "${YELLOW}Installazione dipendenze core (Arch)...${NC}"
yay -S --needed --noconfirm \
    docker \
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
    bind \
    gnu-netcat \
    python \
    python-pip \
    jq \
    unzip \
    wordlists \
    go \
    macchanger \
    net-tools \
    theharvester \
    dirsearch \
    subfinder \
    nuclei \
    ffuf \
    amass \
    gospider

# Python requirements
echo -e "${YELLOW}Installazione dipendenze Python...${NC}"
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt --break-system-packages 2>/dev/null || pip install -r requirements.txt
fi

# Setup Docker
echo -e "${YELLOW}Configurazione Docker...${NC}"
sudo systemctl enable --now docker.service

# Ensure docker group exists and add users
sudo groupadd -f docker
CURRENT_USER=$(logname || echo $SUDO_USER)
if [ -n "$CURRENT_USER" ]; then
    sudo usermod -aG docker "$CURRENT_USER"
fi

# Setup anon user
echo -e "${YELLOW}Setup user anon...${NC}"
if ! id "anon" &>/dev/null; then
    sudo useradd -m -s /bin/bash anon
fi
sudo usermod -aG docker anon
# Add anon to sudoers? (Optional, kept from debian script)
# echo "anon ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/anon

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
sudo chmod +x /usr/local/bin/anon-mode

# Install killchain-hub and lib
echo -e "${YELLOW}Installazione killchain-hub...${NC}"
sudo cp killchain-hub.sh /usr/local/bin/killchain-hub
sudo chmod +x /usr/local/bin/killchain-hub

# Copy lib directory
sudo mkdir -p /usr/local/bin/lib
if [ -d "lib" ]; then
    sudo cp -r lib/* /usr/local/bin/lib/
    sudo chmod +x /usr/local/bin/lib/*.sh
fi

# Install status-check script
if [ -f "status-check.sh" ]; then
    sudo cp status-check.sh /usr/local/bin/status-check
    sudo chmod +x /usr/local/bin/status-check
fi

# Setup Tor config (Arch path might differ, usually same /etc/tor/torrc)
echo -e "${YELLOW}Configurazione Tor...${NC}"
sudo systemctl enable --now tor
if [ ! -f /etc/torsocks.conf ]; then
    sudo bash -c 'cat > /etc/torsocks.conf << EOF
server = 127.0.0.1
server_port = 9050
server_type = 5
EOF'
fi

# Log dir
sudo mkdir -p /home/anon/killchain_logs
sudo chown anon:anon /home/anon/killchain_logs
sudo chmod 755 /home/anon/killchain_logs

echo -e "\n${GREEN}✓ Installazione Arch completata!${NC}"
echo "Nota: su Arch theHarvester è installato nativamente. Docker è facoltativo per questo tool."
