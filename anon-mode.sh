#!/bin/bash
# anon-mode v1.1 - Switch to pentest user with stealth settings

# Ensure we are running in bash
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Helper function for silent command execution
silent() {
    "$@" >/dev/null 2>&1
}

# Check if already anon
if [ "$(whoami)" = "anon" ]; then
    echo -e "${YELLOW}Già loggato come 'anon'${NC}"
    echo "User: $(whoami) | Hostname: $(hostname)"
    echo "Killchain-hub pronto!"
    exit 0
fi

# Check if anon user exists
if ! id "anon" >/dev/null 2>&1; then
    echo -e "${RED}User 'anon' non esiste!${NC}"
    echo -e "${YELLOW}Crea user con:${NC}"
    echo "  sudo useradd -m -s /bin/bash anon"
    # Only suggest sudo group if sudo exists
    if command -v sudo >/dev/null 2>&1; then
        echo "  sudo usermod -aG sudo anon"
        echo "  echo 'anon ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/anon"
    fi
    exit 1
fi

# Ensure anon is in docker group if docker is present
if command -v docker >/dev/null 2>&1; then
    if ! id -nG anon | grep -qw "docker"; then
        echo -e "${YELLOW}⚠ Aggiunta 'anon' al gruppo docker...${NC}"
        if [ "$(id -u)" -eq 0 ] || sudo -n true 2>/dev/null; then
            sudo usermod -aG docker anon >/dev/null 2>&1 || true
        fi
    fi
fi

# Check sudo access for anon (if sudo is available)
if command -v sudo >/dev/null 2>&1; then
    if ! sudo -l -U anon 2>/dev/null | grep -q "NOPASSWD"; then
        echo -e "${YELLOW}⚠ Configurazione sudo per 'anon'...${NC}"
        if [ "$(id -u)" -eq 0 ] || sudo -n true 2>/dev/null; then
             echo "anon ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/anon >/dev/null 2>&1
             sudo chmod 440 /etc/sudoers.d/anon 2>/dev/null
        else
             echo -e "${RED}Impossibile configurare sudo automaticamente. Richiesti privilegi root.${NC}"
        fi
    fi
    # Ensure anon is in standard groups for system access
    for group in users std; do
        if getent group "$group" >/dev/null 2>&1 && ! id -nG anon | grep -qw "$group"; then
            sudo usermod -aG "$group" anon >/dev/null 2>&1 || true
        fi
    done
fi

# Ensure correct permissions for the current directory so anon can write reports/data
echo -e "${YELLOW}Aggiornamento permessi cartella (RWX) per accesso 'anon'...${NC}"
CURRENT_DIR="$(pwd)"
PARENT_DIR=$(dirname "$CURRENT_DIR")

# Fix parent directory traversal permissions first
if [[ "$PARENT_DIR" =~ ^/home/[^/]+$ ]] && [ -d "$PARENT_DIR" ]; then
    if [ ! -r "$PARENT_DIR" ] || [ ! -x "$PARENT_DIR" ]; then
        echo -e "${YELLOW}Fixing traverse permissions on $PARENT_DIR...${NC}"
        if [ "$(id -u)" -eq 0 ]; then
            chmod o+x "$PARENT_DIR" 2>/dev/null || true
        elif command -v sudo >/dev/null 2>&1; then
            sudo chmod o+x "$PARENT_DIR" 2>/dev/null || true
        fi
    fi
fi

# Fix current directory permissions
if [ -w "$CURRENT_DIR" ]; then
    chmod -R 755 "$CURRENT_DIR" 2>/dev/null || true
    # Ensure anon can write to specific subdirectories that might be created
    mkdir -p "$CURRENT_DIR/logs" "$CURRENT_DIR/reports" "$CURRENT_DIR/output" 2>/dev/null || true
    chmod -R 777 "$CURRENT_DIR/logs" "$CURRENT_DIR/reports" "$CURRENT_DIR/output" 2>/dev/null || true
elif command -v sudo >/dev/null 2>&1; then
    sudo chmod -R 755 "$CURRENT_DIR" 2>/dev/null || true
    # Ensure anon can write to specific subdirectories that might be created
    sudo mkdir -p "$CURRENT_DIR/logs" "$CURRENT_DIR/reports" "$CURRENT_DIR/output" 2>/dev/null || true
    sudo chmod -R 777 "$CURRENT_DIR/logs" "$CURRENT_DIR/reports" "$CURRENT_DIR/output" 2>/dev/null || true
fi

# Ensure anon's home directory exists and has proper permissions
if [ ! -d "/home/anon" ]; then
    echo -e "${YELLOW}Creating anon home directory...${NC}"
    if [ "$(id -u)" -eq 0 ]; then
        mkdir -p /home/anon
        chown anon:anon /home/anon
        chmod 755 /home/anon
    elif command -v sudo >/dev/null 2>&1; then
        sudo mkdir -p /home/anon
        sudo chown anon:anon /home/anon
        sudo chmod 755 /home/anon
    fi
fi

# Setup Go environment for anon user
echo -e "${YELLOW}Setting up Go environment for anon user...${NC}"
if [ "$(id -u)" -eq 0 ]; then
    # Create Go workspace for anon
    mkdir -p /home/anon/go/bin 2>/dev/null || true
    chown -R anon:anon /home/anon/go 2>/dev/null || true
    
    # Add Go PATH to anon's bashrc for persistent sessions
    if ! grep -q "go/bin" /home/anon/.bashrc 2>/dev/null; then
        echo 'export GOPATH=$HOME/go' >> /home/anon/.bashrc
        echo 'export PATH=$PATH:$HOME/go/bin:/usr/local/go/bin' >> /home/anon/.bashrc
    fi
    
    # Ensure anon can access system-wide Go tools
    chmod -R +x /usr/local/bin/{nuclei,subfinder,gospider,puredns,dnsx,httpx,alterx} 2>/dev/null || true
    
elif command -v sudo >/dev/null 2>&1; then
    # Create Go workspace for anon
    sudo mkdir -p /home/anon/go/bin 2>/dev/null || true
    sudo chown -R anon:anon /home/anon/go 2>/dev/null || true
    
    # Add Go PATH to anon's bashrc for persistent sessions
    if ! sudo grep -q "go/bin" /home/anon/.bashrc 2>/dev/null; then
        sudo bash -c 'echo "export GOPATH=\$HOME/go" >> /home/anon/.bashrc'
        sudo bash -c 'echo "export PATH=\$PATH:\$HOME/go/bin:/usr/local/go/bin" >> /home/anon/.bashrc'
    fi
    
    # Ensure anon can access system-wide Go tools
    sudo chmod -R +x /usr/local/bin/{nuclei,subfinder,gospider,puredns,dnsx,httpx,alterx} 2>/dev/null || true
fi

# Pre-switch cleanup
echo -e "${CYAN}Pulizia sessione corrente...${NC}"
history -c >/dev/null 2>&1 || true
unset HISTFILE HISTFILESIZE HISTSIZE >/dev/null 2>&1 || true

# Change hostname for stealth (only if systemd/hostnamectl is available and working)
if command -v hostnamectl >/dev/null 2>&1; then
    sudo hostnamectl set-hostname pentest-lab >/dev/null 2>&1 || true
fi

echo -e "${GREEN}=== SWITCHING TO ANON MODE ===${NC}"
echo -e "Da: ${YELLOW}$(whoami)$(tput sgr0)@$(hostname)${NC}"
echo -e "A:   ${CYAN}anon@pentest-lab (virtual)${NC}"
echo ""

# Switch user with environment
stty echo 2>/dev/null || true
# Include Go tools PATH for both system-wide and user installations
ENV_CMD="export TMPDIR=/tmp; export HOME=/home/anon; export PATH=\$PATH:/usr/local/bin:/usr/sbin:/sbin:/usr/local/go/bin:\$HOME/go/bin; export GOPATH=\$HOME/go; stty sane; stty echo; exec /bin/bash -l"
if command -v sudo >/dev/null 2>&1; then
    exec sudo -u anon /bin/bash -l -c "$ENV_CMD"
else
    # Fallback to su if sudo is missing
    exec su - anon -c "$ENV_CMD"
fi
