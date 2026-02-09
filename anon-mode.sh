#!/bin/bash
# anon-mode v1.0 - Switch to pentest user with stealth settings

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# Check if already anon
if [ "$(whoami)" = "anon" ]; then
    echo -e "${YELLOW}Già loggato come 'anon'${NC}"
    echo "User: $(whoami) | Hostname: $(hostname)"
    echo "Killchain-hub pronto!"
    exit 0
fi

# Check if anon user exists
if ! id "anon" &>/dev/null; then
    echo -e "${RED}User 'anon' non esiste!${NC}"
    echo -e "${YELLOW}Crea user con:${NC}"
    echo "  sudo useradd -m -s /bin/bash anon"
    echo "  sudo usermod -aG sudo anon"
    echo "  echo 'anon ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/anon"
    exit 1
fi

# Check sudo access for anon
if ! sudo -l -U anon 2>/dev/null | grep -q "NOPASSWD"; then
    echo -e "${YELLOW}⚠ Configurazione sudo per 'anon'...${NC}"
    echo "anon ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/anon >/dev/null
    sudo chmod 440 /etc/sudoers.d/anon
fi

# Pre-switch cleanup
echo -e "${CYAN}Pulizia sessione corrente...${NC}"
history -c 2>/dev/null || true
unset HISTFILE HISTFILESIZE HISTSIZE 2>/dev/null || true

# Change hostname for stealth
sudo hostnamectl set-hostname pentest-lab 2>/dev/null || true

echo -e "${GREEN}=== SWITCHING TO ANON MODE ===${NC}"
echo -e "Da: ${YELLOW}$(whoami)$(tput sgr0)@$(hostname)${NC}"
echo -e "A:   ${CYAN}anon@pentest-lab${NC}"
echo ""

# Switch user with environment
exec sudo -u anon -i

# Post-login (executed as anon)
# Note: The following runs after exec, so it won't execute in parent
# But we can set it in .bashrc of anon
