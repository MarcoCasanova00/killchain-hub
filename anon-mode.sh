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

# Check sudo access for anon (if sudo is available)
if command -v sudo >/dev/null 2>&1; then
    if ! sudo -l -U anon 2>/dev/null | grep -q "NOPASSWD"; then
        echo -e "${YELLOW}⚠ Configurazione sudo per 'anon'...${NC}"
        # We might not be able to write to /etc/sudoers.d if we are not root/sudoer ourselves
        if [ "$(id -u)" -eq 0 ] || sudo -n true 2>/dev/null; then
             echo "anon ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/anon >/dev/null 2>&1
             sudo chmod 440 /etc/sudoers.d/anon 2>/dev/null
        else
             echo -e "${RED}Impossibile configurare sudo automaticamente. Richiesti privilegi root.${NC}"
        fi
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
if command -v sudo >/dev/null 2>&1; then
    exec sudo -u anon -i
else
    # Fallback to su if sudo is missing
    exec su - anon
fi
