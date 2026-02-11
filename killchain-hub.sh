#!/bin/bash
# Killchain Hub v5.0 - Enhanced with Logging + Advanced Tools + Report Generation

# Ensure we are running in bash
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

# Reset terminal to sane state to fix any residual echo/input issues
stty sane 2>/dev/null

VERSION="5.0"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging library
if [ -f "$SCRIPT_DIR/lib/logger.sh" ]; then
    source "$SCRIPT_DIR/lib/logger.sh"
elif [ -f "./lib/logger.sh" ]; then
    source "./lib/logger.sh"
elif [ -f "/usr/local/bin/lib/logger.sh" ]; then
    source "/usr/local/bin/lib/logger.sh"
else
    echo -e "${RED}ERROR: logger.sh not found!${NC}"
    echo "Expected at: $SCRIPT_DIR/lib/logger.sh"
    echo "Or at: ./lib/logger.sh"
    exit 1
fi

# ===== CONFIGURATION =====
# Load default config
if [ -f "$HOME/.killchain-hub.conf" ]; then
    source "$HOME/.killchain-hub.conf"
elif [ -f "/home/anon/.killchain-hub.conf" ]; then
    source "/home/anon/.killchain-hub.conf"
else
    # Fallback defaults if config missing
    DEFAULT_WORDLIST="/usr/share/wordlists/dirb/common.txt"
    DEFAULT_PASSLIST="/usr/share/wordlists/rockyou.txt"
    GOBUSTER_THREADS=50
    GOSPIDER_THREADS=50
    GOSPIDER_DEPTH=10
    FFUF_THREADS=40
    HYDRA_THREADS=4
    NMAP_TIMING=4
    NMAP_OPTIONS="-sC -sV"
    THEHARVESTER_LIMIT=500
fi

# Defaults for Docker-based theHarvester
# Can be overridden in ~/.killchain-hub.conf
THEHARVESTER_DOCKER_IMAGE="${THEHARVESTER_DOCKER_IMAGE:-kalilinux/kali-rolling}"
# If set to "true", assume image already has theHarvester installed and skip apt each run
THEHARVESTER_DOCKER_PREBUILT="${THEHARVESTER_DOCKER_PREBUILT:-false}"

# ===== GO / TOOL INSTALL HELPERS (Wizard runtime) =====

# Ensure Go toolchain is available for anon (used to install Go-based tools on the fly)
ensure_go_runtime() {
    if command -v go >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${YELLOW}Go (golang-go) non trovato. Alcuni tool (subfinder, puredns, dnsx, ecc.) richiedono Go.${NC}"
    echo -ne "Installare Go e dipendenze base ora tramite apt? [Y/n]: "
    read GO_ANSWER
    if [[ ! "$GO_ANSWER" =~ ^[Yy]$ ]]; then
        log_info "User skipped Go installation"
        return 1
    fi

    log_info "Installing Go toolchain via apt (golang-go, git, build-essential)"
    if sudo apt update && sudo apt install -y golang-go git build-essential; then
        # Ensure ~/go/bin is on PATH for current session and future shells
        if ! echo "$PATH" | grep -q "$HOME/go/bin"; then
            echo 'export PATH=$PATH:$HOME/go/bin' >> "$HOME/.bashrc"
            export PATH="$PATH:$HOME/go/bin"
        fi
        log_success "Go toolchain installed successfully"
        return 0
    else
        log_error "Failed to install Go via apt"
        return 1
    fi
}

# Install a Go-based tool for the current user using "go install"
install_go_tool_runtime() {
    local tool="$1"
    local install_cmd=""

    case "$tool" in
        subfinder)
            install_cmd="go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
            ;;
        puredns)
            install_cmd="go install github.com/d3mondev/puredns/v2@latest"
            ;;
        dnsx)
            install_cmd="go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
            ;;
        alterx)
            install_cmd="go install -v github.com/projectdiscovery/alterx/cmd/alterx@latest"
            ;;
        httpx)
            install_cmd="go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
            ;;
        nuclei)
            install_cmd="go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
            ;;
        trufflehog)
            install_cmd="go install github.com/trufflesecurity/trufflehog/v3@latest"
            ;;
        *)
            log_error "No Go install recipe defined for tool: $tool"
            return 1
            ;;
    esac

    if ! ensure_go_runtime; then
        return 1
    fi

    log_info "Installing $tool via Go: $install_cmd"
    # Filter out noisy "go: downloading" lines for cleaner UX
    eval "$install_cmd" 2>&1 | grep -v "go: downloading" || true

    # Ensure ~/go/bin is in PATH for this session
    if ! echo "$PATH" | grep -q "$HOME/go/bin"; then
        export PATH="$PATH:$HOME/go/bin"
    fi

    if command -v "$tool" >/dev/null 2>&1; then
        log_success "$tool installed successfully via Go"
        return 0
    else
        log_error "Go install command completed but '$tool' not found in PATH"
        return 1
    fi
}

# Install jq via apt when needed (used for crt.sh parsing)
install_jq_if_needed() {
    if command -v jq >/dev/null 2>&1; then
        return 0
    fi
    echo -e "${YELLOW}jq non trovato (richiesto per parsing JSON da crt.sh).${NC}"
    echo -ne "Installare jq ora tramite apt? [Y/n]: "
    read JQ_ANSWER
    if [[ ! "$JQ_ANSWER" =~ ^[Yy]$ ]]; then
        log_info "User skipped jq installation"
        return 1
    fi
    log_info "Installing jq via apt"
    if sudo apt update && sudo apt install -y jq; then
        log_success "jq installed successfully"
        return 0
    else
        log_error "Failed to install jq via apt"
        return 1
    fi
}

# Install cloud_enum from GitHub (optional, uses sudo for wrapper in /usr/local/bin)
install_cloud_enum_runtime() {
    if command -v cloud_enum >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${YELLOW}cloud_enum non trovato.${NC}"
    echo -ne "Installare cloud_enum (git clone + pip) ora? [Y/n]: "
    read CE_ANSWER
    if [[ ! "$CE_ANSWER" =~ ^[Yy]$ ]]; then
        log_info "User skipped cloud_enum installation"
        return 1
    fi

    log_info "Installing cloud_enum from GitHub (initstring/cloud_enum)"
    if ! command -v git >/dev/null 2>&1 || ! command -v pip3 >/dev/null 2>&1; then
        log_info "Ensuring git and python3-pip are installed via apt"
        sudo apt update && sudo apt install -y git python3-pip || {
            log_error "Failed to install git/python3-pip for cloud_enum"
            return 1
        }
    fi

    local CE_DIR="$HOME/cloud_enum"
    rm -rf "$CE_DIR"
    if ! git clone --quiet https://github.com/initstring/cloud_enum.git "$CE_DIR"; then
        log_error "git clone for cloud_enum failed"
        return 1
    fi

    if ! pip3 install --user -r "$CE_DIR/requirements.txt"; then
        log_error "pip install requirements for cloud_enum failed"
        return 1
    fi

    # Create a small wrapper so "cloud_enum" is in PATH
    local WRAP="/usr/local/bin/cloud_enum"
    echo '#!/bin/bash' | sudo tee "$WRAP" >/dev/null
    echo "python3 \"$CE_DIR/cloud_enum.py\" \"\$@\"" | sudo tee -a "$WRAP" >/dev/null
    sudo chmod +x "$WRAP"

    if command -v cloud_enum >/dev/null 2>&1; then
        log_success "cloud_enum installed successfully"
        return 0
    else
        log_error "cloud_enum wrapper created but not found in PATH"
        return 1
    fi
}

# Generic checker used by the wizard steps
check_and_install_tool() {
    local tool="$1"      # binary name to check
    local method="$2"    # "go", "jq-apt", "cloud_enum", or "none"

    if command -v "$tool" >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${YELLOW}Tool '$tool' non trovato nel PATH.${NC}"
    echo -ne "Installare '$tool' ora? [Y/n]: "
    read TOOL_ANSWER
    if [[ ! "$TOOL_ANSWER" =~ ^[Yy]$ ]]; then
        log_info "User skipped installation of $tool"
        return 1
    fi

    local ok=1
    case "$method" in
        go)
            install_go_tool_runtime "$tool" && ok=0
            ;;
        jq-apt)
            install_jq_if_needed && ok=0
            ;;
        cloud_enum)
            install_cloud_enum_runtime && ok=0
            ;;
        *)
            log_error "No install method defined for tool: $tool"
            ok=1
            ;;
    esac

    if [ $ok -ne 0 ]; then
        echo -ne "${RED}Installazione di '$tool' fallita. Continuare comunque? [y/N]: ${NC}"
        read CONTINUE_ANSWER
        if [[ "$CONTINUE_ANSWER" =~ ^[Yy]$ ]]; then
            log_error "Continuing without $tool at user request"
            return 1
        else
            log_error "Aborting due to missing tool: $tool"
            finalize_logging
            exit 1
        fi
    fi

    return 0
}

# ===== FORCE ANON USER CHECK =====
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" != "anon" ]; then
    echo -e "${RED}⚠ ATTENZIONE: Sei loggato come '$CURRENT_USER'${NC}"
    echo -e "${YELLOW}Questo script DEVE essere eseguito come 'anon'${NC}"
    echo ""
    echo "Fix: lancia 'anon-mode' prima di eseguire killchain-hub"
    exit 1
fi

# ===== AUTO-DETECT PROXY =====
# Check config preference first
if [ -n "$PREFERRED_PROXY" ] && command -v "$PREFERRED_PROXY" >/dev/null 2>&1; then
    PROXY="$PREFERRED_PROXY"
elif command -v torsocks >/dev/null 2>&1; then
    PROXY="torsocks"
elif command -v proxychains4 >/dev/null 2>&1; then
    PROXY="proxychains4"
elif command -v proxychains >/dev/null 2>&1; then
    PROXY="proxychains"
else
    echo -e "${RED}ERRORE: Nessun proxy Tor installato!${NC}"
    echo "Fix: sudo apt install -y torsocks tor"
    exit 1
fi

# ===== DOCKER CHECK =====
# Try to find docker in common paths if not in PATH
if ! command -v docker >/dev/null 2>&1; then
    if [ -x "/usr/bin/docker" ]; then
        export PATH=$PATH:/usr/bin
    elif [ -x "/usr/local/bin/docker" ]; then
        export PATH=$PATH:/usr/local/bin
    else
        echo -e "${RED}Docker non installato o non trovato nel PATH!${NC}"
        echo "PATH attuale: $PATH"
        echo "Fix: sudo apt install -y docker.io && sudo usermod -aG docker anon"
        exit 1
    fi
fi

# ===== TOR CHECK =====
# Robust check for Tor port
if command -v ss >/dev/null 2>&1; then
    if ! sudo ss -tlnp 2>/dev/null | grep -q 9050; then
        TOR_MISSING=true
    fi
elif command -v netstat >/dev/null 2>&1; then
    if ! sudo netstat -tlnp 2>/dev/null | grep -q 9050; then
        TOR_MISSING=true
    fi
fi

if [ "$TOR_MISSING" = "true" ]; then
    echo -e "${YELLOW}⚠ Tor non rilevato sulla porta 9050${NC}"
    echo "Avvio Tor..."
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl start tor >/dev/null 2>&1
    elif command -v service >/dev/null 2>&1; then
        sudo service tor start >/dev/null 2>&1
    else
        sudo tor & >/dev/null 2>&1
    fi
    sleep 2
fi

clear
echo -e "${CYAN}"
echo "     \\ /"
echo "     oVo"
echo " \\___XXX___/"
echo "  __XXXXX__"
echo " /__XXXXX__\\"
echo " /   XXX   \\"
echo "      V"
echo -e "${NC}"
echo -e "${GREEN}=== KILLCHAIN HUB v${VERSION} ===${NC}"
echo -e "${YELLOW}Coded by SteveLithium${NC}"
echo ""
echo "User: ${CYAN}$CURRENT_USER${NC} | Proxy: ${CYAN}$PROXY${NC}"
echo "theHarvester: ${BLUE}Docker Kali (Python 3.12 fix)${NC}"

# Test Tor IP
TOR_IP=$($PROXY curl -s --max-time 5 ifconfig.me 2>/dev/null || echo 'N/A')
echo "IP Tor: ${CYAN}$TOR_IP${NC}"
echo "======================================================"

# ===== LOG DIRECTORY SETUP =====
LOGBASE="${LOG_BASE_DIR:-/home/anon/killchain_logs}"
mkdir -p "$LOGBASE" 2>/dev/null || {
    echo -e "${RED}Errore: impossibile creare $LOGBASE${NC}"
    exit 1
}
chmod 755 "$LOGBASE"
echo -e "Logs base: ${YELLOW}$LOGBASE/${NC}\n"

# ===== INPUT =====
echo -ne "Target dominio (es. esempio.it): "
read TARGET
[ -z "$TARGET" ] && { echo -e "${RED}Target richiesto!${NC}"; exit 1; }

SESSION_DEFAULT="${TARGET}_$(date +%Y%m%d_%H%M%S)"
echo -ne "Nome cartella log per questa sessione (default: ${SESSION_DEFAULT}): "
read SESSION_NAME
SESSION_NAME=${SESSION_NAME:-"$SESSION_DEFAULT"}

# Basic sanitization (spazi → underscore)
SESSION_NAME_SANITIZED=$(echo "$SESSION_NAME" | tr ' ' '_')

echo -ne "Email list file (opz): "
read EMAILLIST
echo -ne "Wordlist ($DEFAULT_WORDLIST): "
read WORDLIST
WORDLIST=${WORDLIST:-"$DEFAULT_WORDLIST"}

# Create session log directory
LOGDIR="$LOGBASE/${SESSION_NAME_SANITIZED}"
mkdir -p "$LOGDIR" || { echo -e "${RED}Errore creazione $LOGDIR${NC}"; exit 1; }
chmod 755 "$LOGDIR"
echo -e "${BLUE}Sessione log: $LOGDIR${NC}\n"

# Initialize logging
init_logging "$LOGDIR"
log_info "Killchain-Hub v${VERSION} started"
log_info "Target: $TARGET"
log_info "Proxy: $PROXY"

# ===== PHASE MENU =====
echo -e "${YELLOW}Seleziona FASE:${NC}"
echo "0) Pre-Flight Check (Verify anonymity & tools)"
echo "1) Recon (Docker-theHarvester/whois/dig)"
echo "2) Scan (nmap/dnsrecon/nikto)"
echo "3) Web Enum (gospider/dirsearch/gobuster)"
echo "4) Brute (hydra SMTP/HTTP)"
echo "5) Evasion Test"
echo "6) Full Auto (Recon Docker → Scan → Web)"
echo "7) Advanced Tools (subfinder/nuclei/sqlmap/ffuf)"
echo "8) Generate Report"
echo "9) Guided Info Gathering Wizard"
echo "10) Assessment Wizard (Passive → Active → Vuln → Exploit helper)"
echo -ne "> "
read FASE

case $FASE in
0)
    log_info "Running pre-flight check"
    
    # Check if preflight script exists
    if [ -f "$SCRIPT_DIR/lib/preflight-check.sh" ]; then
        bash "$SCRIPT_DIR/lib/preflight-check.sh"
    elif [ -f "./lib/preflight-check.sh" ]; then
        bash "./lib/preflight-check.sh"
    elif [ -f "/usr/local/bin/lib/preflight-check.sh" ]; then
        bash "/usr/local/bin/lib/preflight-check.sh"
    else
        log_error "Pre-flight check script not found"
        echo -e "${RED}Pre-flight check script not found!${NC}"
        echo "Expected at: $SCRIPT_DIR/lib/preflight-check.sh"
        exit 1
    fi
    
    PREFLIGHT_EXIT=$?
    if [ $PREFLIGHT_EXIT -eq 0 ]; then
        log_success "Pre-flight check passed"
    else
        log_error "Pre-flight check failed"
    fi
    
    finalize_logging
    exit $PREFLIGHT_EXIT
    ;;
1)
    echo ""
    echo "1) theHarvester (Docker Kali / Native)"
    echo "2) whois+dig (local)"
    echo "3) amass (subdomain/attack surface recon)"
    echo "4) recon-ng (interactive OSINT framework)"
    echo "5) SpiderFoot (web UI OSINT)"
    echo -ne "Tool (1-5): "
    read TOOL
    
    if [ "$TOOL" = "1" ]; then
        # Prioritize native theHarvester on Kali and other systems
        if command -v theHarvester &>/dev/null; then
             log_info "Starting theHarvester (Native)"
             CMD="theHarvester -d $TARGET -l $THEHARVESTER_LIMIT -b all -f ${LOGDIR}/${TARGET}_report"
             echo -e "${GREEN}✓ Using native theHarvester (no Docker needed)${NC}"
        elif [ -f /etc/os-release ] && grep -q "kali" /etc/os-release; then
            # Kali-specific fallback: install theHarvester if missing
            echo -e "${YELLOW}theHarvester not found on Kali. Installing...${NC}"
            if command -v sudo >/dev/null 2>&1; then
                sudo apt update -qq && sudo apt install -y theharvester 2>/dev/null || true
            fi
            if command -v theHarvester &>/dev/null; then
                log_info "Starting theHarvester (Native - Kali installed)"
                CMD="theHarvester -d $TARGET -l $THEHARVESTER_LIMIT -b all -f ${LOGDIR}/${TARGET}_report"
                echo -e "${GREEN}✓ Using native theHarvester (installed on Kali)${NC}"
            else
                echo -e "${RED}Failed to install theHarvester on Kali. Please install manually.${NC}"
                return 1
            fi
        else
            # Docker theHarvester with optional prebuilt image
            log_info "Starting theHarvester via Docker (image: $THEHARVESTER_DOCKER_IMAGE, prebuilt=$THEHARVESTER_DOCKER_PREBUILT)"
            if [ "$THEHARVESTER_DOCKER_PREBUILT" = "true" ]; then
                # Prebuilt image is expected to already have theHarvester installed
                CMD="docker run --rm -u root -v $LOGBASE:/logs \"$THEHARVESTER_DOCKER_IMAGE\" bash -lc 'mkdir -p /tmp/harvester && theHarvester -d $TARGET -l $THEHARVESTER_LIMIT -b all -f /tmp/harvester/${TARGET}_report && cp /tmp/harvester/${TARGET}_report.* /logs/ 2>/dev/null; chmod 666 /logs/${TARGET}_report.* 2>/dev/null; exit 0' && sudo chown -R anon:anon $LOGBASE"
            else
                # Default behaviour: try apt first, then fall back to GitHub (pip) inside Kali
                CMD="docker run --rm -u root -v $LOGBASE:/logs \"$THEHARVESTER_DOCKER_IMAGE\" bash -lc '
set -e
if ! command -v theHarvester >/dev/null 2>&1; then
  echo \"[theHarvester] Installing via apt inside container...\"
  if ! (apt update -qq && apt install -yq theharvester); then
    echo \"[theHarvester] apt install failed, trying GitHub (pip) fallback...\"
    apt install -yq git python3-pip >/dev/null 2>&1 || true
    pip3 install --no-cache-dir git+https://github.com/laramies/theHarvester.git || true
  fi
fi
if ! command -v theHarvester >/dev/null 2>&1; then
  echo \"[theHarvester] still not installed inside container, aborting.\"
  exit 1
fi
mkdir -p /tmp/harvester
theHarvester -d $TARGET -l $THEHARVESTER_LIMIT -b all -f /tmp/harvester/${TARGET}_report
cp /tmp/harvester/${TARGET}_report.* /logs/ 2>/dev/null || true
chmod 666 /logs/${TARGET}_report.* 2>/dev/null || true
exit 0
' && sudo chown -R anon:anon $LOGBASE"
                echo -e "${BLUE}Info: Docker scarica Kali (~150MB cache prima volta); if apt fails, it will try GitHub (pip) inside the container.${NC}"
            fi
        fi
    elif [ "$TOOL" = "2" ]; then
        log_info "Starting whois and DNS enumeration"
        CMD="whois $TARGET > ${LOGDIR}/whois.txt && dig MX $TARGET +short > ${LOGDIR}/mx.txt && dig NS $TARGET +short > ${LOGDIR}/ns.txt && dig A $TARGET +short > ${LOGDIR}/a.txt"
    elif [ "$TOOL" = "3" ]; then
        if ! command -v amass &>/dev/null; then
            log_error "amass not installed. Run Pre-Flight (0) and install it or rerun the system installer."
            echo -e "${RED}amass non installato!${NC}"
            exit 1
        fi
        log_info "Starting amass reconnaissance"
        # Amass (Go binary) often has issues with torsocks fork/exec.
        # Prefer proxychains/proxychains4 if available, or run direct if torsocks is the only one.
        if command -v proxychains4 >/dev/null 2>&1; then
            CMD="proxychains4 amass enum -d $TARGET -o ${LOGDIR}/amass.txt"
        elif command -v proxychains >/dev/null 2>&1; then
            CMD="proxychains amass enum -d $TARGET -o ${LOGDIR}/amass.txt"
        else
            # If only torsocks is available, we use it but warn
            CMD="$PROXY amass enum -d $TARGET -o ${LOGDIR}/amass.txt"
            echo -e "${YELLOW}⚠ Using torsocks with Amass. If it fails, install proxychains4.${NC}"
        fi
    elif [ "$TOOL" = "4" ]; then
        if ! command -v recon-ng &>/dev/null; then
            log_error "recon-ng not installed. Run Pre-Flight (0) and install it or use your package manager."
            echo -e "${RED}recon-ng non installato!${NC}"
            exit 1
        fi
        log_info "Launching recon-ng interactive console"
        CMD="$PROXY recon-ng"
    elif [ "$TOOL" = "5" ]; then
        if ! command -v spiderfoot &>/dev/null; then
            log_error "SpiderFoot not installed. Run Pre-Flight (0) and install it or use your package manager."
            echo -e "${RED}SpiderFoot non installato!${NC}"
            exit 1
        fi
        log_info "Starting SpiderFoot web UI on 127.0.0.1:5001"
        CMD="$PROXY spiderfoot -l 127.0.0.1:5001 & echo 'SpiderFoot listening on http://127.0.0.1:5001 (CTRL+C to stop in that terminal)'"
    else
        echo -e "${RED}Tool invalido!${NC}"; exit 1
    fi
    ;;
2)
    echo ""
    echo "1) nmap  2) dnsrecon  3) nikto"
    echo -ne "Tool (1-3): "
    read TOOL
    
    if [ "$TOOL" = "1" ]; then
        # IP Resolution
        RESOLVED_IP=$(dig +short "$TARGET" | head -n1)
        if [ -z "$RESOLVED_IP" ]; then
            RESOLVED_IP=$(getent hosts "$TARGET" | awk '{print $1}' | head -n1)
        fi
        
        echo -e "\n${YELLOW}Target Resolution:${NC}"
        echo -e "Domain: ${CYAN}$TARGET${NC}"
        echo -e "IP:     ${CYAN}${RESOLVED_IP:-N/A}${NC}"
        
        SCAN_TARGET="$TARGET"
        if [ -n "$RESOLVED_IP" ]; then
            echo -ne "Scan [D]omain or [I]P? (default: Domain): "
            read TARGET_CHOICE
            if [[ "$TARGET_CHOICE" =~ ^[Ii]$ ]]; then
                SCAN_TARGET="$RESOLVED_IP"
                log_info "User selected to scan IP: $SCAN_TARGET"
            fi
        fi
        
        echo -e "\n${YELLOW}Nmap Configuration:${NC}"
        echo -e "Default flags: ${CYAN}$NMAP_OPTIONS${NC}"
        echo -ne "Use default flags? [Y/n]: "
        read FLAG_CHOICE
        if [[ "$FLAG_CHOICE" =~ ^[Nn]$ ]]; then
            echo -ne "Enter custom flags (e.g. -p- -A -T4): "
            read CUSTOM_FLAGS
            if [ -n "$CUSTOM_FLAGS" ]; then
                NMAP_OPTIONS="$CUSTOM_FLAGS"
            fi
        fi

        # Force safe flags for Proxy/Tor usage to avoid SIGABRT (134)
        # -sT: Connect scan (required, no raw sockets)
        # -Pn: No Ping (required, Tor drops ICMP)
        # -n:  No DNS (required, prevents leaking/failures)
        if [ -n "$PROXY" ]; then
            FORCE_FLAGS="-sT -Pn -n"
            echo -e "${YELLOW}ℹ Proxy rilevato: forzo flags di stabilità ($FORCE_FLAGS).${NC}"
            
            # Prepend flags if not present
            [[ ! "$NMAP_OPTIONS" =~ "-sT" ]] && NMAP_OPTIONS="-sT $NMAP_OPTIONS"
            [[ ! "$NMAP_OPTIONS" =~ "-Pn" ]] && NMAP_OPTIONS="-Pn $NMAP_OPTIONS"
            [[ ! "$NMAP_OPTIONS" =~ "-n" ]] && NMAP_OPTIONS="-n $NMAP_OPTIONS"
        fi
        
        log_info "Starting nmap scan on $SCAN_TARGET with flags: $NMAP_OPTIONS"
        CMD="$PROXY nmap $NMAP_OPTIONS -T$NMAP_TIMING $SCAN_TARGET -oN ${LOGDIR}/nmap.txt"
    elif [ "$TOOL" = "2" ]; then
        log_info "Starting DNS reconnaissance"
        CMD="$PROXY dnsrecon -d $TARGET -t brt -c ${LOGDIR}/dnsrecon.csv"
    elif [ "$TOOL" = "3" ]; then
        log_info "Starting Nikto web scan"
        CMD="$PROXY nikto -h https://$TARGET -output ${LOGDIR}/nikto.txt"
    else
        echo -e "${RED}Tool invalido!${NC}"; exit 1
    fi
    ;;
3)
    echo ""
    echo "1) gospider  2) dirsearch  3) gobuster"
    echo -ne "Tool (1-3): "
    read TOOL
    echo -ne "Depth ($GOSPIDER_DEPTH): "
    read DEPTH; DEPTH=${DEPTH:-$GOSPIDER_DEPTH}
    
    if [ "$TOOL" = "1" ]; then
        log_info "Starting gospider crawling"
        CMD="$PROXY gospider -s https://$TARGET -d $DEPTH -t $GOSPIDER_THREADS -o ${LOGDIR}/gospider/"
    elif [ "$TOOL" = "2" ]; then
        log_info "Starting dirsearch enumeration"
        CMD="$PROXY dirsearch -u https://$TARGET -w $WORDLIST --random-agent -o ${LOGDIR}/dirsearch.txt"
    elif [ "$TOOL" = "3" ]; then
        log_info "Starting gobuster directory brute force"
        CMD="$PROXY gobuster dir -u https://$TARGET -w $WORDLIST -t $GOBUSTER_THREADS -o ${LOGDIR}/gobuster.txt"
    else
        echo -e "${RED}Tool invalido!${NC}"; exit 1
    fi
    ;;
4)
    [ -z "$EMAILLIST" ] && { echo -e "${RED}Email list richiesta! Usa Fase 1 prima.${NC}"; exit 1; }
    [ ! -f "$EMAILLIST" ] && { echo -e "${RED}File $EMAILLIST non trovato!${NC}"; exit 1; }
    
    echo ""
    echo "1) Hydra SMTP  2) Hydra HTTP"
    echo -ne "Tool (1-2): "
    read TOOL
    
    PASSLIST="${DEFAULT_PASSLIST:-/usr/share/wordlists/rockyou.txt}"
    [ ! -f "$PASSLIST" ] && { echo -e "${RED}$PASSLIST mancante!${NC}"; exit 1; }
    
    if [ "$TOOL" = "1" ]; then
        echo -ne "Mail server (smtp.$TARGET): "
        read MAILSRV
        MAILSRV=${MAILSRV:-"smtp.$TARGET"}
        log_info "Starting Hydra SMTP brute force"
        CMD="$PROXY hydra -L $EMAILLIST -P $PASSLIST $MAILSRV smtp -t $HYDRA_THREADS -o ${LOGDIR}/hydra_smtp.txt"
    elif [ "$TOOL" = "2" ]; then
        echo -ne "Login path (/login): "
        read LP
        log_info "Starting Hydra HTTP brute force"
        CMD="$PROXY hydra -L $EMAILLIST -P $PASSLIST $TARGET http-post-form \"$LP:user=^USER^&pass=^PASS^:F=incorrect\" -o ${LOGDIR}/hydra_http.txt"
    else
        echo -e "${RED}Tool invalido!${NC}"; exit 1
    fi
    ;;
5)
    log_info "Evasion Menu Selected"
    echo -e "\n${BLUE}=== Evasion & Anonymity ===${NC}"
    echo "1) Check Current Status (Safe)"
    echo "2) Apply Enhanced Evasion Mode (REQUIRES SUDO)"
    echo "   - Disables IPv6"
    echo "   - Forces DNS to Tor (127.0.0.1)"
    echo "   - Activates Firewall Kill Switch for 'anon'"
    echo "   - Clears Logs & History"
    echo -ne "\nSelect option (1-2): "
    read EV_CHOICE
    
    if [ "$EV_CHOICE" = "2" ]; then
        log_info "Applying enhanced evasion measures"
        # Check if enhanced evasion script exists
        if [ -f "$SCRIPT_DIR/lib/evasion.sh" ]; then
            sudo bash "$SCRIPT_DIR/lib/evasion.sh" | tee "${LOGDIR}/evasion_apply.txt"
        elif [ -f "./lib/evasion.sh" ]; then
            sudo bash "./lib/evasion.sh" | tee "${LOGDIR}/evasion_apply.txt"
        elif [ -f "/usr/local/bin/lib/evasion.sh" ]; then
            sudo bash "/usr/local/bin/lib/evasion.sh" | tee "${LOGDIR}/evasion_apply.txt"
        else
            log_error "Evasion script not found"
            echo -e "${RED}Evasion script not found!${NC}"
        fi
    else
        log_info "Running evasion test only"
        # Run pre-flight check in evasion mode (or just basic IP check)
        CMD="echo 'Real IP:' && curl -s --max-time 5 ifconfig.me && echo -e '\nTor IP:' && $PROXY curl -s --max-time 5 ifconfig.me && echo -e '\n[!] Run Option 0 (Pre-Flight) for full details.'"
        eval "$CMD"
    fi
    
    log_success "Evasion step completed"
    finalize_logging
    exit 0
    ;;
6)
    log_info "Starting FULL AUTO MODE"
    echo -e "\n${BLUE}=== FULL AUTO MODE ===${NC}"
    echo -e "${YELLOW}[1/3] Recon via Docker Kali...${NC}\n"
    
    # Fase 1 - Reconnaissance
    if command -v theHarvester &>/dev/null; then
         log_command "theHarvester reconnaissance (Native)" "theHarvester -d $TARGET -l $THEHARVESTER_LIMIT -b bing,linkedin,google -f ${LOGDIR}/${TARGET}_auto"
    else
         if [ "$THEHARVESTER_DOCKER_PREBUILT" = "true" ]; then
             log_command "theHarvester reconnaissance (Docker prebuilt image)" "docker run --rm -u root -v $LOGBASE:/logs \"$THEHARVESTER_DOCKER_IMAGE\" bash -lc \"mkdir -p /tmp/harvester && theHarvester -d $TARGET -l $THEHARVESTER_LIMIT -b bing,linkedin,google -f /tmp/harvester/${TARGET}_auto && cp /tmp/harvester/${TARGET}_auto.* /logs/ 2>/dev/null; chmod 666 /logs/${TARGET}_auto.* 2>/dev/null; exit 0\""
         else
             log_command "theHarvester reconnaissance (Docker Kali)" "docker run --rm -u root -v $LOGBASE:/logs \"$THEHARVESTER_DOCKER_IMAGE\" bash -lc '
set -e
if ! command -v theHarvester >/dev/null 2>&1; then
  echo \"[theHarvester] Installing via apt inside container...\"
  if ! (apt update -qq && apt install -yq theharvester); then
    echo \"[theHarvester] apt install failed, trying GitHub (pip) fallback...\"
    apt install -yq git python3-pip >/dev/null 2>&1 || true
    pip3 install --no-cache-dir git+https://github.com/laramies/theHarvester.git || true
  fi
fi
if ! command -v theHarvester >/dev/null 2>&1; then
  echo \"[theHarvester] still not installed inside container, aborting.\"
  exit 1
fi
mkdir -p /tmp/harvester
theHarvester -d $TARGET -l $THEHARVESTER_LIMIT -b bing,linkedin,google -f /tmp/harvester/${TARGET}_auto
cp /tmp/harvester/${TARGET}_auto.* /logs/ 2>/dev/null || true
chmod 666 /logs/${TARGET}_auto.* 2>/dev/null || true
exit 0
'"
         fi
         sudo chown -R anon:anon $LOGBASE
    fi
    
    echo -e "\n${YELLOW}[2/3] Nmap scan...${NC}\n"
    log_command "Nmap port scan" "$PROXY nmap $NMAP_OPTIONS -T$NMAP_TIMING $TARGET -oN ${LOGDIR}/nmap.txt"
    
    echo -e "\n${YELLOW}[3/3] Web enumeration...${NC}\n"
    log_command "Dirsearch web enumeration" "$PROXY dirsearch -u https://$TARGET -w $WORDLIST --random-agent -o ${LOGDIR}/dirsearch.txt"
    
    log_success "Full auto scan completed"
    CMD="echo 'Full Auto Mode Completed'"
    ;;
7)
    echo ""
    echo "1) subfinder (subdomain enum)"
    echo "2) nuclei (vulnerability scan)"
    echo "3) sqlmap (SQL injection)"
    echo "4) ffuf (fuzzer)"
    echo "5) subfinder + nuclei (enum → vuln scan)"
    echo -ne "Tool (1-5): "
    read TOOL
    
    if [ "$TOOL" = "1" ]; then
        if ! command -v subfinder &>/dev/null; then
            log_error "subfinder not installed. Run: sudo apt install subfinder"
            exit 1
        fi
        log_info "Starting subfinder subdomain enumeration"
        CMD="$PROXY subfinder -d $TARGET -o ${LOGDIR}/subfinder.txt -silent"
    elif [ "$TOOL" = "2" ]; then
        if ! command -v nuclei &>/dev/null; then
            log_error "nuclei not installed. Run: sudo apt install nuclei"
            exit 1
        fi
        log_info "Starting nuclei vulnerability scan"
        CMD="$PROXY nuclei -u https://$TARGET -o ${LOGDIR}/nuclei.txt"
    elif [ "$TOOL" = "3" ]; then
        echo -ne "Target URL (https://$TARGET/page?id=1): "
        read SQLURL
        SQLURL=${SQLURL:-"https://$TARGET"}
        log_info "Starting sqlmap SQL injection scan"
        CMD="$PROXY sqlmap -u \"$SQLURL\" --batch --output-dir=${LOGDIR}/sqlmap"
    elif [ "$TOOL" = "4" ]; then
        if ! command -v ffuf &>/dev/null; then
            log_error "ffuf not installed. Run: sudo apt install ffuf"
            exit 1
        fi
        log_info "Starting ffuf fuzzing"
        CMD="$PROXY ffuf -u https://$TARGET/FUZZ -w $WORDLIST -o ${LOGDIR}/ffuf.json -of json -t $FFUF_THREADS"
    elif [ "$TOOL" = "5" ]; then
        # Chain: subfinder → nuclei over discovered subdomains
        if ! command -v subfinder &>/dev/null; then
            log_error "subfinder not installed. Run Pre-Flight (0) and install it or use your package manager."
            echo -e "${RED}subfinder non installato!${NC}"
            exit 1
        fi
        if ! command -v nuclei &>/dev/null; then
            log_error "nuclei not installed. Run Pre-Flight (0) and install it or use your package manager."
            echo -e "${RED}nuclei non installato!${NC}"
            exit 1
        fi
        log_info "Starting chained subfinder + nuclei workflow"
        CMD="$PROXY subfinder -d $TARGET -silent -o ${LOGDIR}/subfinder.txt && $PROXY nuclei -l ${LOGDIR}/subfinder.txt -o ${LOGDIR}/nuclei_from_subfinder.txt"
    else
        echo -e "${RED}Tool invalido!${NC}"; exit 1
    fi
    ;;
8)
    log_info "Generating session report"
    
    REPORT_FILE="${LOGDIR}/report.html"
    
    cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Killchain-Hub Report - $TARGET</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #1e1e1e; color: #d4d4d4; }
        h1 { color: #4ec9b0; }
        h2 { color: #569cd6; border-bottom: 2px solid #569cd6; padding-bottom: 5px; }
        .info { background: #2d2d30; padding: 15px; border-radius: 5px; margin: 10px 0; }
        .file { background: #252526; padding: 10px; margin: 5px 0; border-left: 3px solid #4ec9b0; }
        pre { background: #1e1e1e; border: 1px solid #3e3e42; padding: 10px; overflow-x: auto; }
        .success { color: #4ec9b0; }
        .warning { color: #ce9178; }
        .error { color: #f48771; }
    </style>
</head>
<body>
    <h1>🎯 Killchain-Hub Security Assessment Report</h1>
    
    <div class="info">
        <h2>Target Information</h2>
        <p><strong>Domain:</strong> $TARGET</p>
        <p><strong>Scan Date:</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>
        <p><strong>User:</strong> $(whoami)</p>
        <p><strong>Session Directory:</strong> $LOGDIR</p>
    </div>
    
    <div class="info">
        <h2>Generated Files</h2>
EOF
    
    # List all log files
    for file in "$LOGDIR"/*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            filesize=$(du -h "$file" | cut -f1)
            echo "        <div class=\"file\">📄 $filename ($filesize)</div>" >> "$REPORT_FILE"
        fi
    done
    
    cat >> "$REPORT_FILE" << EOF
    </div>
    
    <div class="info">
        <h2>Session Log</h2>
        <pre>$(cat ${LOGDIR}/session.log 2>/dev/null || echo "No session log available")</pre>
    </div>
    
    <div class="info">
        <h2>Errors</h2>
        <pre class="error">$(cat ${LOGDIR}/errors.log 2>/dev/null || echo "No errors logged")</pre>
    </div>
    
    <footer style="margin-top: 30px; text-align: center; color: #858585;">
        <p>Generated by Killchain-Hub v${VERSION}</p>
    </footer>
</body>
</html>
EOF
    
    log_success "Report generated: $REPORT_FILE"
    echo -e "${GREEN}Open in browser: file://$REPORT_FILE${NC}"
    
    finalize_logging
    exit 0
    ;;
9)
    log_info "Starting Guided Info Gathering Wizard"
    echo -e "\n${BLUE}=== Guided Info Gathering & Enumeration ===${NC}"
    echo -e "${YELLOW}This wizard follows your manual workflow: whois → ASN/range → Shodan/FOFA/dorks → subdomains → DNS permutations → certificates → cloud/secrets.${NC}\n"

    # STEP 1: whois + dig on domain and IP
    echo -e "${BLUE}[1/6] whois + dig (domain & IP)${NC}"
    WHOIS_FILE="${LOGDIR}/whois_domain.txt"
    DIG_A_FILE="${LOGDIR}/dig_a.txt"
    DIG_MX_FILE="${LOGDIR}/dig_mx.txt"
    DIG_NS_FILE="${LOGDIR}/dig_ns.txt"

    echo -e "${YELLOW}Running whois on domain...${NC}"
    whois "$TARGET" > "$WHOIS_FILE" 2>/dev/null || echo -e "${YELLOW}whois failed or returned no data for $TARGET${NC}"

    echo -e "${YELLOW}Running dig (A / MX / NS)...${NC}"
    dig "$TARGET" +short > "$DIG_A_FILE" 2>/dev/null || true
    dig MX "$TARGET" +short > "$DIG_MX_FILE" 2>/dev/null || true
    dig NS "$TARGET" +short > "$DIG_NS_FILE" 2>/dev/null || true

    # Extract inetnum / route / origin ASN from whois (if present)
    INETNUM=$(grep -m1 -E "inetnum:" "$WHOIS_FILE" 2>/dev/null | awk '{$1=""; sub(/^ /,""); print}')
    ROUTE=$(grep -m1 -E "route:" "$WHOIS_FILE" 2>/dev/null | awk '{$1=""; sub(/^ /,""); print}')
    ASN=$(grep -m1 -E "origin:" "$WHOIS_FILE" 2>/dev/null | awk '{$1=""; sub(/^ /,""); print}')

    echo -e "\n${CYAN}Summary from whois:${NC}"
    [ -n "$INETNUM" ] && echo "  inetnum: $INETNUM"
    [ -n "$ROUTE" ] && echo "  route:   $ROUTE"
    [ -n "$ASN" ] && echo "  origin:  $ASN"
    echo -e "\nwhois saved to:      ${YELLOW}$WHOIS_FILE${NC}"
    echo -e "dig A records:       ${YELLOW}$DIG_A_FILE${NC}"
    echo -e "dig MX records:      ${YELLOW}$DIG_MX_FILE${NC}"
    echo -e "dig NS records:      ${YELLOW}$DIG_NS_FILE${NC}\n"

    echo -ne "${YELLOW}Press ENTER to continue to Shodan/FOFA & Google dorks...${NC}"
    read

    # STEP 2: Shodan / FOFA / Google Dorks hints
    echo -e "\n${BLUE}[2/6] Shodan / FOFA / Google Dorks${NC}"
    echo -e "${YELLOW}Use these queries in Shodan/FOFA/Google based on whois output.${NC}\n"

    if [ -n "$ROUTE" ]; then
        echo "Shodan by network range (from 'route' or 'inetnum'):"
        echo "  ip:${ROUTE}"
        echo ""
    elif [ -n "$INETNUM" ]; then
        echo "Shodan by network range (from 'inetnum'):"
        echo "  ip:${INETNUM}"
        echo ""
    fi

    if [ -n "$ASN" ]; then
        echo "Shodan/FOFA by ASN:"
        echo "  ASN: ${ASN}"
        echo ""
    fi

    echo "Google dorks examples:"
    echo "  site:*.${TARGET}"
    echo "  site:*.${TARGET} intext:\"index of\""
    echo ""

    echo -ne "${YELLOW}Press ENTER to continue to passive subdomain enumeration (subfinder)...${NC}"
    read

    # STEP 3: Passive subdomain enumeration (subfinder)
    echo -e "\n${BLUE}[3/6] Passive Subdomain Enumeration (subfinder)${NC}"
    SUBF_FILE="${LOGDIR}/subfinder.txt"
    # Try to ensure subfinder is available via Go installer
    check_and_install_tool "subfinder" "go" || true
    if command -v subfinder >/dev/null 2>&1; then
        echo -e "${YELLOW}Running subfinder...${NC}"
        $PROXY subfinder -d "$TARGET" -silent -o "$SUBF_FILE" 2>/dev/null || true
        echo -e "subfinder output saved to: ${YELLOW}$SUBF_FILE${NC}"
    else
        echo -e "${RED}subfinder non installato.${NC}"
        echo "You can install it via installer / Pre-Flight (0) or rerun this wizard and run manually:"
        echo "  subfinder -d $TARGET -silent -o $SUBF_FILE"
    fi

    echo -ne "${YELLOW}Press ENTER to continue to active DNS brute/permutations (puredns / alterx / dnsx)...${NC}"
    read

    # STEP 4: Active DNS brute & permutations (puredns / alterx / dnsx)
    echo -e "\n${BLUE}[4/6] Active DNS brute & permutations${NC}"
    echo -e "${YELLOW}This step is optional and depends on extra tools (puredns, alterx, dnsx).${NC}\n"

    # Try to ensure Go-based DNS tools are available
    check_and_install_tool "puredns" "go" || true
    check_and_install_tool "alterx" "go" || true
    check_and_install_tool "dnsx" "go" || true

    if command -v puredns >/dev/null 2>&1; then
        echo "Example puredns command:"
        echo "  puredns bruteforce /path/to/wordlist.txt $TARGET -r resolvers.txt -w ${LOGDIR}/puredns.txt"
    else
        echo "puredns not found. Install it if you want active DNS brute-force."
    fi
    echo ""

    if command -v alterx >/dev/null 2>&1 && command -v dnsx >/dev/null 2>&1; then
        echo "Example permutation + resolution chain using alterx + dnsx:"
        echo "  cat ${SUBF_FILE:-subdomains.txt} | alterx | dnsx -o ${LOGDIR}/dnsx.txt"
    else
        echo "alterx and/or dnsx not found."
        echo "Example (manual) from your notes:"
        echo "  cat filesottodomini.txt | alterx | dnsx"
    fi
    echo ""

    echo -ne "${YELLOW}Press ENTER to continue to certificate-based subdomains (crt.sh)...${NC}"
    read

    # STEP 5: crt.sh certificate enumeration
    echo -e "\n${BLUE}[5/6] Certificate-based subdomains (crt.sh)${NC}"
    CRT_FILE="${LOGDIR}/crtsh_${TARGET}.json"
    # Ensure jq is available if possible
    install_jq_if_needed || true
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}Querying crt.sh and saving raw JSON to:${NC} ${YELLOW}$CRT_FILE${NC}"
        curl -s "https://crt.sh/?q=${TARGET}&output=json" > "$CRT_FILE" 2>/dev/null || echo -e "${YELLOW}crt.sh request failed or returned no data.${NC}"
        echo ""
        echo "Manual example (same as your notes):"
        echo "  curl -s \"https://crt.sh/?q=${TARGET}&output=json\" | jq -r '.[].name_value' | sort -u"
    else
        echo -e "${RED}curl and/or jq not available; cannot auto-query crt.sh.${NC}"
        echo "Use this command manually:"
        echo "  curl -s \"https://crt.sh/?q=${TARGET}&output=json\" | jq -r '.[].name_value' | sort -u"
    fi

    echo -ne "${YELLOW}Press ENTER to continue to cloud/secrets/favicon helpers...${NC}"
    read

    # STEP 6: Cloud buckets, secrets, favicon-based hunting
    echo -e "\n${BLUE}[6/6] Cloud buckets, secrets & favicon hunting${NC}"

    echo -e "\n${CYAN}Cloud storage discovery (grayhatwarfare / cloud_enum):${NC}"
    # Try to install cloud_enum if missing
    check_and_install_tool "cloud_enum" "cloud_enum" || true
    if command -v cloud_enum >/dev/null 2>&1; then
        echo "Example cloud_enum usage:"
        echo "  cloud_enum -k \"${TARGET}\" -o ${LOGDIR}/cloud_enum_${TARGET}.txt"
    else
        echo "cloud_enum not found. From your notes:"
        echo "  Use grayhatwarfare.com UI or the cloud_enum CLI to search misconfigured buckets."
    fi

    echo -e "\n${CYAN}Secrets in repositories (GitHub dorks / TruffleHog):${NC}"
    # Ensure trufflehog is available via Go installer if possible
    check_and_install_tool "trufflehog" "go" || true
    if command -v trufflehog >/dev/null 2>&1; then
        echo "Example TruffleHog usage (after git clone /tmp/repo):"
        echo "  trufflehog --regex --entropy=False /tmp/repo"
    else
        echo "trufflehog not found. Manual command from your notes:"
        echo "  trufflehog --regex --entropy=False /tmp/repo"
    fi

    echo -e "\n${CYAN}Favicon-based hunting (favfreak/favhash + Shodan icon_hash):${NC}"
    echo "Example Shodan dork:"
    echo "  icon_hash=\"0000000\""
    echo "Compute the favicon hash with favfreak/favhash, then search that hash on Shodan."

    echo -e "\n${GREEN}Guided Info Gathering Wizard completed.${NC}"
    echo -e "All artifacts saved under: ${YELLOW}$LOGDIR${NC}"

    log_success "Guided Info Gathering Wizard completed"
    finalize_logging
    exit 0
    ;;
*)
    log_error "Fase invalida: $FASE"
    echo -e "${RED}Fase invalida!${NC}"
    exit 1
    ;;
esac

# Execute command
echo ""
echo -e "${CYAN}Esecuzione comando...${NC}"
echo ""

eval "$CMD"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    log_success "Command completed successfully"
else
    log_error "Command failed with exit code $EXIT_CODE"
fi

# Finalize logging
finalize_logging

echo ""
echo -e "${GREEN}=== Completato ===${NC}"
echo -e "Logs salvati in: ${YELLOW}$LOGDIR${NC}"
echo ""

exit $EXIT_CODE
