#!/bin/bash
# Killchain Hub v5.0 - Enhanced with Logging + Advanced Tools + Report Generation

# Ensure we are running in bash
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

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
elif [ -f "/usr/local/bin/lib/logger.sh" ]; then
    source "/usr/local/bin/lib/logger.sh"
else
    echo -e "${RED}ERROR: logger.sh not found!${NC}"
    echo "Expected at: $SCRIPT_DIR/lib/logger.sh"
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
read -p "Target dominio (es. esempio.it): " TARGET
[ -z "$TARGET" ] && { echo -e "${RED}Target richiesto!${NC}"; exit 1; }

read -p "Email list file (opz): " EMAILLIST
read -p "Wordlist ($DEFAULT_WORDLIST): " WORDLIST
WORDLIST=${WORDLIST:-"$DEFAULT_WORDLIST"}

# Create session log directory
LOGDIR="$LOGBASE/${TARGET}_$(date +%Y%m%d_%H%M%S)"
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
read -p "> " FASE

case $FASE in
0)
    log_info "Running pre-flight check"
    
    # Check if preflight script exists
    if [ -f "$SCRIPT_DIR/lib/preflight-check.sh" ]; then
        bash "$SCRIPT_DIR/lib/preflight-check.sh"
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
    echo "1) theHarvester (Docker Kali)"
    echo "2) whois+dig (local)"
    read -p "Tool (1-2): " TOOL
    
    if [ "$TOOL" = "1" ]; then
        # Docker theHarvester con fix permissions
        log_info "Starting theHarvester via Docker"
        CMD="docker run --rm -u root -v $LOGBASE:/logs kalilinux/kali-rolling bash -lc 'apt update -qq && apt install -yq theharvester && mkdir -p /tmp/harvester && theHarvester -d $TARGET -l $THEHARVESTER_LIMIT -b all -f /tmp/harvester/${TARGET}_report && cp /tmp/harvester/${TARGET}_report.* /logs/ 2>/dev/null; chmod 666 /logs/${TARGET}_report.* 2>/dev/null; exit 0' && sudo chown -R anon:anon $LOGBASE"
        
        echo -e "${BLUE}Info: Docker scarica Kali (~150MB cache prima volta)${NC}"
    elif [ "$TOOL" = "2" ]; then
        log_info "Starting whois and DNS enumeration"
        CMD="whois $TARGET > ${LOGDIR}/whois.txt && dig MX $TARGET +short > ${LOGDIR}/mx.txt && dig NS $TARGET +short > ${LOGDIR}/ns.txt && dig A $TARGET +short > ${LOGDIR}/a.txt"
    else
        echo -e "${RED}Tool invalido!${NC}"; exit 1
    fi
    ;;
2)
    echo ""
    echo "1) nmap  2) dnsrecon  3) nikto"
    read -p "Tool (1-3): " TOOL
    
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
            read -p "Scan [D]omain or [I]P? (default: Domain): " TARGET_CHOICE
            if [[ "$TARGET_CHOICE" =~ ^[Ii]$ ]]; then
                SCAN_TARGET="$RESOLVED_IP"
                log_info "User selected to scan IP: $SCAN_TARGET"
            fi
        fi
        
        echo -e "\n${YELLOW}Nmap Configuration:${NC}"
        echo -e "Default flags: ${CYAN}$NMAP_OPTIONS${NC}"
        read -p "Use default flags? [Y/n]: " FLAG_CHOICE
        if [[ "$FLAG_CHOICE" =~ ^[Nn]$ ]]; then
            read -p "Enter custom flags (e.g. -p- -A -T4): " CUSTOM_FLAGS
            if [ -n "$CUSTOM_FLAGS" ]; then
                NMAP_OPTIONS="$CUSTOM_FLAGS"
            fi
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
    read -p "Tool (1-3): " TOOL
    read -p "Depth ($GOSPIDER_DEPTH): " DEPTH; DEPTH=${DEPTH:-$GOSPIDER_DEPTH}
    
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
    read -p "Tool (1-2): " TOOL
    
    PASSLIST="${DEFAULT_PASSLIST:-/usr/share/wordlists/rockyou.txt}"
    [ ! -f "$PASSLIST" ] && { echo -e "${RED}$PASSLIST mancante!${NC}"; exit 1; }
    
    if [ "$TOOL" = "1" ]; then
        read -p "Mail server (smtp.$TARGET): " MAILSRV
        MAILSRV=${MAILSRV:-"smtp.$TARGET"}
        log_info "Starting Hydra SMTP brute force"
        CMD="$PROXY hydra -L $EMAILLIST -P $PASSLIST $MAILSRV smtp -t $HYDRA_THREADS -o ${LOGDIR}/hydra_smtp.txt"
    elif [ "$TOOL" = "2" ]; then
        read -p "Login path (/login): " LP
        log_info "Starting Hydra HTTP brute force"
        CMD="$PROXY hydra -L $EMAILLIST -P $PASSLIST $TARGET http-post-form \"$LP:user=^USER^&pass=^PASS^:F=incorrect\" -o ${LOGDIR}/hydra_http.txt"
    else
        echo -e "${RED}Tool invalido!${NC}"; exit 1
    fi
    ;;
5)
    log_info "Running enhanced evasion test"
    
    # Check if enhanced evasion script exists
    if [ -f "$SCRIPT_DIR/lib/evasion.sh" ]; then
        bash "$SCRIPT_DIR/lib/evasion.sh" | tee "${LOGDIR}/evasion.txt"
    elif [ -f "/usr/local/bin/lib/evasion.sh" ]; then
        bash "/usr/local/bin/lib/evasion.sh" | tee "${LOGDIR}/evasion.txt"
    else
        # Fallback to basic test
        log_warning "Enhanced evasion script not found, using basic test"
        CMD="echo 'Real IP:' && curl -s ifconfig.me && echo -e '\nTor IP:' && $PROXY curl -s ifconfig.me && echo -e '\nTest salvato in ${LOGDIR}/evasion.txt' && { echo \"Real: \$(curl -s ifconfig.me)\"; echo \"Tor: \$($PROXY curl -s ifconfig.me)\"; } > ${LOGDIR}/evasion.txt"
        eval "$CMD"
    fi
    
    log_success "Evasion test completed"
    finalize_logging
    exit 0
    ;;
6)
    log_info "Starting FULL AUTO MODE"
    echo -e "\n${BLUE}=== FULL AUTO MODE ===${NC}"
    echo -e "${YELLOW}[1/3] Recon via Docker Kali...${NC}\n"
    
    # Fase 1 - Docker theHarvester
    log_command "theHarvester reconnaissance" "docker run --rm -u root -v $LOGBASE:/logs kalilinux/kali-rolling bash -lc \"apt update -qq && apt install -yq theharvester && mkdir -p /tmp/harvester && theHarvester -d $TARGET -l $THEHARVESTER_LIMIT -b bing,linkedin,google -f /tmp/harvester/${TARGET}_auto && cp /tmp/harvester/${TARGET}_auto.* /logs/ 2>/dev/null; chmod 666 /logs/${TARGET}_auto.* 2>/dev/null; exit 0\""
    
    sudo chown -R anon:anon $LOGBASE
    
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
    read -p "Tool (1-4): " TOOL
    
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
        read -p "Target URL (https://$TARGET/page?id=1): " SQLURL
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
