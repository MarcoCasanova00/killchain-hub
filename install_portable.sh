#!/bin/bash
# Killchain Hub v5.0 Portable Installer
# For minimal Linux distributions (Arch, Alpine, Debian minimal, etc.)
# Uses binary releases and static builds where possible

if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo "=== Killchain Hub Portable Installer v5.0 ==="
echo "${BLUE}Minimal Linux - Static builds and binary releases${NC}"

# Detect package manager
detect_package_manager() {
    if command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v apk >/dev/null 2>&1; then
        echo "apk"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    else
        echo "unknown"
    fi
}

PKG_MANAGER=$(detect_package_manager)
echo -e "${YELLOW}Package manager detected: ${PKG_MANAGER}${NC}"

# Check if running as root (optional for portable install)
if [ "$EUID" -eq 0 ]; then 
    echo -e "${YELLOW}Running as root. Will install system-wide.${NC}"
    SYSTEM_INSTALL=true
else
    echo -e "${YELLOW}Running as user. Will install in \$HOME/.local${NC}"
    SYSTEM_INSTALL=false
    PREFIX="$HOME/.local"
    mkdir -p "$PREFIX/bin" "$PREFIX/lib"
fi

# Install basic dependencies based on package manager
install_basic_deps() {
    echo -e "${YELLOW}Installing basic dependencies...${NC}"
    
    case $PKG_MANAGER in
        "pacman")
            if [ "$SYSTEM_INSTALL" = true ]; then
                sudo pacman -Syu --noconfirm
                sudo pacman -S --needed --noconfirm base-devel curl wget git unzip tar glibc
            else
                echo -e "${YELLOW}Please install: sudo pacman -S base-devel curl wget git unzip tar${NC}"
            fi
            ;;
        "apt")
            if [ "$SYSTEM_INSTALL" = true ]; then
                sudo apt update && sudo apt install -y curl wget git unzip tar build-essential
            else
                echo -e "${YELLOW}Please install: sudo apt install curl wget git unzip tar build-essential${NC}"
            fi
            ;;
        "apk")
            if [ "$SYSTEM_INSTALL" = true ]; then
                sudo apk update && sudo apk add curl wget git unzip tar build-base
            else
                echo -e "${YELLOW}Please install: sudo apk add curl wget git unzip tar build-base${NC}"
            fi
            ;;
        "dnf"|"yum")
            if [ "$SYSTEM_INSTALL" = true ]; then
                sudo $PKG_MANAGER install -y curl wget git unzip tar gcc make
            else
                echo -e "${YELLOW}Please install: sudo $PKG_MANAGER install curl wget git unzip tar gcc make${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Unknown package manager. Please install: curl, wget, git, unzip, tar, build tools${NC}"
            ;;
    esac
}

install_basic_deps

# Function to download binary from GitHub releases
download_github_binary() {
    local name=$1
    local repo=$2
    local binary_name=${3:-$1}
    local version=${4:-"latest"}
    
    echo -e "${YELLOW}[*] Installing ${name}...${NC}"
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) G_ARCH="amd64" ;;
        aarch64) G_ARCH="arm64" ;;
        armv7l) G_ARCH="armv7" ;;
        *) G_ARCH="amd64" ;;
    esac
    
    # Get release info
    if [ "$version" = "latest" ]; then
        RELEASE_URL="https://api.github.com/repos/$repo/releases/latest"
    else
        RELEASE_URL="https://api.github.com/repos/$repo/releases/tags/$version"
    fi
    
    # Get download URL
    DOWNLOAD_URL=$(curl -s "$RELEASE_URL" | \
        jq -r ".assets[] | select(.name | contains(\"linux\") and contains(\"$G_ARCH\") and (contains(\"tar.gz\") or contains(\"zip\") or contains(\"tar.bz2\"))) | .browser_download_url" | head -n 1)
    
    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
        echo -e "${RED}✗ Could not find suitable release for ${name}${NC}"
        return 1
    fi
    
    # Download and extract
    TEMP_DIR="/tmp/${name}_install"
    mkdir -p "$TEMP_DIR"
    
    echo -e "${BLUE}  Downloading: ${DOWNLOAD_URL##*/}${NC}"
    curl -L "$DOWNLOAD_URL" -o "$TEMP_DIR/archive"
    
    if [[ "$DOWNLOAD_URL" == *.zip ]]; then
        unzip -q "$TEMP_DIR/archive" -d "$TEMP_DIR"
    else
        tar -xzf "$TEMP_DIR/archive" -C "$TEMP_DIR"
    fi
    
    # Find and copy binary
    BINARY_PATH=$(find "$TEMP_DIR" -type f -name "$binary_name" -executable | head -n 1)
    if [ -n "$BINARY_PATH" ]; then
        if [ "$SYSTEM_INSTALL" = true ]; then
            sudo cp "$BINARY_PATH" /usr/local/bin/
            sudo chmod +x /usr/local/bin/"$binary_name"
        else
            cp "$BINARY_PATH" "$PREFIX/bin/"
            chmod +x "$PREFIX/bin/$binary_name"
        fi
        echo -e "${GREEN}✓ ${name} installed${NC}"
    else
        echo -e "${RED}✗ Binary not found in archive${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    rm -rf "$TEMP_DIR"
}

# Function to install Go tool from source (if binary not available)
install_go_from_source() {
    local name=$1
    local repo=$2
    local import_path=$3
    
    echo -e "${YELLOW}[*] Installing ${name} from source...${NC}"
    
    # Install Go if not present
    if ! command -v go >/dev/null 2>&1; then
        echo -e "${YELLOW}Installing Go...${NC}"
        GO_VERSION="1.21.6"
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) GO_ARCH="amd64" ;;
            aarch64) GO_ARCH="arm64" ;;
            *) GO_ARCH="amd64" ;;
        esac
        
        curl -L "https://golang.org/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" | tar -C /usr/local -xzf -
        export PATH=$PATH:/usr/local/go/bin
    fi
    
    # Set up GOPATH
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin
    mkdir -p "$GOPATH"
    
    # Install tool
    go install "$import_path@latest"
    
    if command -v "$name" >/dev/null 2>&1; then
        if [ "$SYSTEM_INSTALL" = true ]; then
            sudo cp "$GOPATH/bin/$name" /usr/local/bin/
        else
            cp "$GOPATH/bin/$name" "$PREFIX/bin/"
        fi
        echo -e "${GREEN}✓ ${name} installed from source${NC}"
    else
        echo -e "${RED}✗ Failed to install ${name}${NC}"
        return 1
    fi
}

# Install Go (required for many tools)
if ! command -v go >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing Go...${NC}"
    GO_VERSION="1.21.6"
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) GO_ARCH="amd64" ;;
        aarch64) GO_ARCH="arm64" ;;
        *) GO_ARCH="amd64" ;;
    esac
    
    if [ "$SYSTEM_INSTALL" = true ]; then
        curl -L "https://golang.org/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" | sudo tar -C /usr/local -xzf -
        sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go
    else
        curl -L "https://golang.org/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" | tar -C "$PREFIX" -xzf -
        export PATH=$PATH:$PREFIX/go/bin
        mkdir -p "$PREFIX/bin"
        ln -sf "$PREFIX/go/bin/go" "$PREFIX/bin/go"
    fi
fi

# Install security tools
echo -e "${YELLOW}Installing security tools (binary releases)...${NC}"

# Core networking tools (try package manager first)
CORE_TOOLS=("nmap" "curl" "wget" "git" "unzip" "tar")
for tool in "${CORE_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo -e "${YELLOW}Installing $tool via package manager...${NC}"
        case $PKG_MANAGER in
            "pacman")
                [ "$SYSTEM_INSTALL" = true ] && sudo pacman -S --needed --noconfirm "$tool" 2>/dev/null || true
                ;;
            "apt")
                [ "$SYSTEM_INSTALL" = true ] && sudo apt install -y "$tool" 2>/dev/null || true
                ;;
            "apk")
                [ "$SYSTEM_INSTALL" = true ] && sudo apk add "$tool" 2>/dev/null || true
                ;;
        esac
    fi
done

# Install Go-based tools via binary releases
download_github_binary "nuclei" "projectdiscovery/nuclei" "nuclei"
download_github_binary "subfinder" "projectdiscovery/subfinder" "subfinder"
download_github_binary "ffuf" "ffuf/ffuf" "ffuf"
download_github_binary "amass" "owasp-amass/amass" "amass"
download_github_binary "gospider" "jaeles-project/gospider" "gospider"

# Install tools that might need source compilation
if ! command -v gobuster >/dev/null 2>&1; then
    install_go_from_source "gobuster" "OJ/gobuster" "github.com/OJ/gobuster/v3/cmd/gobuster@latest"
fi

# Install Python tools via pip (portable)
echo -e "${YELLOW}Installing Python tools...${NC}"

# Check for Python
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}Python 3 not found. Please install Python 3 first.${NC}"
    exit 1
fi

# Install pip if missing
if ! command -v pip3 >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing pip...${NC}"
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3
fi

# Install Python tools in user space
pip3 install --user -r requirements.txt 2>/dev/null || {
    echo -e "${YELLOW}Installing essential Python tools manually...${NC}"
    pip3 install --user dirsearch sqlmap requests beautifulsoup4 2>/dev/null || true
}

# Install theHarvester (Python)
if ! command -v theHarvester >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing theHarvester...${NC}"
    pip3 install --user theHarvester 2>/dev/null || {
        # Fallback to git install
        git clone https://github.com/laramies/theHarvester.git /tmp/theHarvester
        cd /tmp/theHarvester
        pip3 install --user -r requirements.txt
        python3 setup.py install --user 2>/dev/null || true
        cd -
        rm -rf /tmp/theHarvester
    }
fi

# Create portable directory structure
echo -e "${YELLOW}Setting up portable structure...${NC}"

if [ "$SYSTEM_INSTALL" = true ]; then
    BASE_DIR="/usr/local"
    BIN_DIR="/usr/local/bin"
    LIB_DIR="/usr/local/bin/lib"
else
    BASE_DIR="$PREFIX"
    BIN_DIR="$PREFIX/bin"
    LIB_DIR="$PREFIX/lib"
fi

# Install killchain-hub script
if [ "$SYSTEM_INSTALL" = true ]; then
    sudo cp killchain-hub.sh "$BIN_DIR/killchain-hub"
    sudo chmod +x "$BIN_DIR/killchain-hub"
else
    cp killchain-hub.sh "$BIN_DIR/killchain-hub"
    chmod +x "$BIN_DIR/killchain-hub"
fi

# Install libraries
mkdir -p "$LIB_DIR"
if [ -d "lib" ]; then
    if [ "$SYSTEM_INSTALL" = true ]; then
        sudo cp -r lib/* "$LIB_DIR/"
        sudo chmod +x "$LIB_DIR"/*.sh
    else
        cp -r lib/* "$LIB_DIR/"
        chmod +x "$LIB_DIR"/*.sh
    fi
fi

# Install aux scripts
if [ -f "status-check.sh" ]; then
    if [ "$SYSTEM_INSTALL" = true ]; then
        sudo cp status-check.sh "$BIN_DIR/status-check"
        sudo chmod +x "$BIN_DIR/status-check"
    else
        cp status-check.sh "$BIN_DIR/status-check"
        chmod +x "$BIN_DIR/status-check"
    fi
fi

# Setup user environment
if [ "$SYSTEM_INSTALL" = true ]; then
    # Create anon user (optional)
    if ! id "anon" &>/dev/null; then
        echo -e "${YELLOW}Creating anon user...${NC}"
        sudo useradd -m -s /bin/bash anon 2>/dev/null || true
        echo "anon ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/anon >/dev/null 2>/dev/null || true
    fi
    
    # anon-mode script
    cat > /usr/local/bin/anon-mode << 'EOF'
#!/bin/bash
if [ "$(whoami)" != "anon" ]; then
    if command -v sudo >/dev/null 2>&1 && id anon >/dev/null 2>&1; then
        sudo -u anon -i
    else
        echo "anon user not available. Continuing as $(whoami)"
    fi
else
    echo "Already logged in as anon"
fi
EOF
    sudo chmod +x /usr/local/bin/anon-mode
    
    # Setup directories
    sudo mkdir -p /home/anon/killchain_logs
    sudo chown anon:anon /home/anon/killchain_logs 2>/dev/null || true
else
    # User-local setup
    mkdir -p "$HOME/killchain_logs"
    
    # Add to PATH if not already
    if ! echo "$PATH" | grep -q "$PREFIX/bin"; then
        echo "export PATH=\$PATH:$PREFIX/bin" >> "$HOME/.bashrc"
    fi
fi

# Create portable config
CONFIG_DIR="$HOME"
if [ "$SYSTEM_INSTALL" = true ] && [ -d "/home/anon" ]; then
    CONFIG_DIR="/home/anon"
fi

if [ -f ".killchain-hub.conf" ]; then
    cp .killchain-hub.conf "$CONFIG_DIR/.killchain-hub.conf"
    # Modify for portable use
    sed -i 's/FORCE_TOR="yes"/FORCE_TOR="no"/' "$CONFIG_DIR/.killchain-hub.conf"
    sed -i 's|THEHARVESTER_DOCKER_IMAGE=".*"|THEHARVESTER_DOCKER_IMAGE=""|' "$CONFIG_DIR/.killchain-hub.conf"
    if [ "$SYSTEM_INSTALL" = true ] && id anon >/dev/null 2>&1; then
        sudo chown anon:anon "$CONFIG_DIR/.killchain-hub.conf"
    fi
fi

echo -e "\n${GREEN}✓ Portable installation completed!${NC}"
echo ""
echo "${BLUE}Installation Summary:${NC}"
if [ "$SYSTEM_INSTALL" = true ]; then
    echo "  • System-wide installation in /usr/local/bin"
    echo "  • User 'anon' created for privacy"
else
    echo "  • User installation in $PREFIX/bin"
    echo "  • Add to PATH: export PATH=\$PATH:$PREFIX/bin"
fi

echo ""
echo "${BLUE}Installed Tools:${NC}"
echo "  • Go-based: nuclei, subfinder, ffuf, amass, gospider"
echo "  • Python: theHarvester, dirsearch, sqlmap"
echo "  • System: nmap, curl, wget, git"

echo ""
echo "${BLUE}Quick Start:${NC}"
if [ "$SYSTEM_INSTALL" = true ]; then
    echo "  ${YELLOW}anon-mode${NC}      # Switch to privacy user"
    echo "  ${YELLOW}killchain-hub${NC}  # Start framework"
else
    echo "  ${YELLOW}killchain-hub${NC}  # Start framework (from $PREFIX/bin)"
fi

echo ""
echo "${YELLOW}Note: This portable version includes minimal dependencies."
echo "      Some tools may need additional system packages for full functionality.${NC}"