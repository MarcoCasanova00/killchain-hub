#!/bin/bash
# Master Installer for Killchain Hub v5.0
# Detects OS and runs appropriate installer

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo "=== Killchain Hub Installer v5.0 ==="
echo "Detecting OS..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
else
    OS=$(uname -s)
fi

echo -e "OS Detected: ${GREEN}$OS${NC}"

if [[ "$OS" == *"Arch"* ]] || [[ "$OS" == *"Manjaro"* ]]; then
    echo -e "${YELLOW}Arch Linux detected. Switching to native Arch installer (pacman/yay)...${NC}"
    chmod +x install_arch.sh
    ./install_arch.sh
elif [[ "$OS" == *"Kali"* ]]; then
    echo -e "${YELLOW}Kali Linux detected. Using optimized Kali installer (native tools, no Docker)...${NC}"
    chmod +x install_kali.sh
    # install_kali.sh expects to be run with sudo
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Running Kali installer requires root. Requesting sudo...${NC}"
        sudo ./install_kali.sh
    else
        ./install_kali.sh
    fi
elif [[ "$OS" == *"Debian"* ]] || [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Parrot"* ]]; then
    echo -e "${YELLOW}Debian/Ubuntu/Parrot detected. Switching to apt installer...${NC}"
    chmod +x install_debian.sh
    # install_debian.sh expects to be run with sudo
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Running Debian installer requires root. Requesting sudo...${NC}"
        sudo ./install_debian.sh
    else
        ./install_debian.sh
    fi
else
    echo -e "${RED}OS not automatically recognized or supported for auto-install.${NC}"
    echo "Please choose manually:"
    echo "1) Kali Linux (optimized, native tools)"
    echo "2) Debian/Ubuntu/Parrot (apt with Docker)"
    echo "3) Arch Linux (pacman/yay)"
    echo "4) Portable (minimal, binary releases)"
    echo -ne "Select (1-4): "
    read CHOICE
    if [ "$CHOICE" == "1" ]; then
        chmod +x install_kali.sh
        sudo ./install_kali.sh
    elif [ "$CHOICE" == "2" ]; then
        chmod +x install_debian.sh
        sudo ./install_debian.sh
    elif [ "$CHOICE" == "3" ]; then
        chmod +x install_arch.sh
        ./install_arch.sh
    elif [ "$CHOICE" == "4" ]; then
        chmod +x install_portable.sh
        ./install_portable.sh
    else
        echo "Invalid choice. Exiting."
        exit 1
    fi
fi
