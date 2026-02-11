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

# Ensure correct permissions for the current directory so anon can read scripts
echo -e "${YELLOW}Aggiornamento permessi cartella per accesso 'anon'...${NC}"
if [ -w "." ]; then
   chmod -R 755 . 2>/dev/null || true
elif command -v sudo >/dev/null 2>&1; then
   sudo chmod -R 755 . 2>/dev/null || true
fi

# Fix traversal permissions if in a home directory (e.g. /home/kali)
PARENT_DIR=$(dirname "$(pwd)")
if [[ "$PARENT_DIR" =~ ^/home/[^/]+$ ]]; then
    if [ ! -r "$PARENT_DIR" ] || [ ! -x "$PARENT_DIR" ]; then
        echo -e "${YELLOW}Fixing traverse permissions on $PARENT_DIR...${NC}"
        sudo chmod o+x "$PARENT_DIR" 2>/dev/null || true
    fi
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
ENV_CMD="export TMPDIR=/tmp; export HOME=/home/anon; export PATH=\$PATH:/usr/local/bin:/usr/sbin:/sbin; stty echo; exec /bin/bash -l"
if command -v sudo >/dev/null 2>&1; then
    exec sudo -u anon /bin/bash -l -c "$ENV_CMD"
else
    # Fallback to su if sudo is missing
    exec su - anon -c "$ENV_CMD"
fi
