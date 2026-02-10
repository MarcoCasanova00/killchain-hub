# Killchain Hub v5.0 🎯

**Automated Penetration Testing Framework** - CLI interattiva per reconnaissance, scanning, web enumeration, brute force e vulnerability assessment con evasion Tor.

## 🚀 Caratteristiche

### Fasi di Attacco
- **Fase 1 - Recon**: theHarvester (Docker Kali), whois, dig, amass, recon-ng, SpiderFoot
- **Fase 2 - Scan**: nmap, dnsrecon, nikto via Tor
- **Fase 3 - Web Enum**: gospider, dirsearch, gobuster
- **Fase 4 - Brute**: Hydra SMTP/HTTP
- **Fase 5 - Evasion**: Test IP Tor/anonimato
- **Fase 6 - Auto**: Killchain completa automatizzata
- **Fase 7 - Advanced**: subfinder, nuclei, sqlmap, ffuf, workflow subfinder→nuclei
- **Fase 8 - Report**: Generazione report HTML

### Funzionalità Avanzate
✅ **Logging centralizzato** con timestamps e livelli (INFO, SUCCESS, WARNING, ERROR)  
✅ **Report HTML** con riepilogo sessione e file generati  
✅ **Tor routing** automatico per tutti i tool  
✅ **Docker isolation** per theHarvester  
✅ **User separation** con anon-mode per stealth operations  

---

## 📋 Requisiti

### Sistema
- Debian 12+ / Ubuntu 22.04+ / Kali Linux
- Python 3.11+
- Docker (per theHarvester)
- Go 1.21+ (per tool avanzati)
- 4GB RAM minimo
- 10GB spazio libero

### Dipendenze
```bash
# Core tools
sudo apt install -y docker.io torsocks tor nmap gobuster hydra nikto dnsrecon

# Advanced tools (installati automaticamente o via Pre-Flight 0)
# subfinder, nuclei, ffuf, amass, gospider

# OSINT opzionale (a seconda della distro / repo):
# spiderfoot, recon-ng
```

---

## 🔧 Installazione

### Metodo 1: Script automatico (consigliato)

```bash
git clone https://github.com/tuo-username/killchain-hub.git
cd killchain-hub
chmod +x install.sh
sudo ./install.sh
```

Lo script installa:
- ✅ Tutti i tool core e avanzati
- ✅ Dipendenze Python da requirements.txt
- ✅ User `anon` per stealth operations
- ✅ Configurazione Tor
- ✅ Docker setup
- ✅ Libreria di logging

### Metodo 2: Manuale

```bash
# Copia script principale
sudo cp killchain-hub.sh /usr/local/bin/killchain-hub
sudo chmod +x /usr/local/bin/killchain-hub

# Copia libreria logging
sudo mkdir -p /usr/local/bin/lib
sudo cp lib/logger.sh /usr/local/bin/lib/
sudo chmod +x /usr/local/bin/lib/logger.sh

# Crea user anon
sudo useradd -m -s /bin/bash anon
sudo usermod -aG sudo,docker anon
echo "anon ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/anon

# Installa dipendenze Python
pip3 install -r requirements.txt
```

---

## 🎮 Utilizzo

### Quick Start

```bash
# 1. Entra in modalità anonima
anon-mode

# 2. Avvia killchain-hub
killchain-hub

# 3. Inserisci target
Target dominio (es. esempio.it): example.com

# 4. Seleziona fase (1-8)
Seleziona FASE:
1) Recon (Docker-theHarvester/whois/dig)
2) Scan (nmap/dnsrecon/nikto)
3) Web Enum (gospider/dirsearch/gobuster)
4) Brute (hydra SMTP/HTTP)
5) Evasion Test
6) Full Auto (Recon Docker → Scan → Web)
7) Advanced Tools (subfinder/nuclei/sqlmap/ffuf)
8) Generate Report
>
```

### Esempi d'Uso

#### Reconnaissance Completo
```bash
killchain-hub
# Target: example.com
# Fase: 1 → Tool: 1 (theHarvester Docker)
```

#### Scan Automatizzato
```bash
killchain-hub
# Target: example.com
# Fase: 6 (Full Auto)
# Esegue: theHarvester → nmap → dirsearch
```

#### Vulnerability Scan
```bash
killchain-hub
# Target: example.com
# Fase: 7 → Tool: 2 (nuclei)
```

#### Generazione Report
```bash
killchain-hub
# Target: example.com
# Fase: 8 (Generate Report)
# Output: /home/anon/killchain_logs/example.com_*/report.html
```

---

## 📁 Struttura Output

I log vengono salvati in `/home/anon/killchain_logs/` con struttura:

```
killchain_logs/
├── example.com_20260209_144500/
│   ├── session.log          # Log completo sessione con timestamps
│   ├── errors.log           # Solo errori
│   ├── whois.txt            # Output whois
│   ├── mx.txt               # Record MX
│   ├── nmap.txt             # Scan nmap
│   ├── dirsearch.txt        # Enumerazione directory
│   ├── subfinder.txt        # Subdomain enumeration
│   ├── nuclei.txt           # Vulnerability scan
│   └── report.html          # Report HTML (Fase 8)
└── example.com_report.json  # theHarvester output (Docker)
```

---

## 🔒 Evasion & Anonimato

### User Separation
```bash
anon-mode  # Switcha a user 'anon' non-root
```
- ✅ Operazioni isolate dall'utente principale
- ✅ History bash disabilitata
- ✅ Hostname cambiato in `pentest-lab`

### Tor Routing
Tutti i tool (tranne theHarvester Docker) passano attraverso Tor:
```bash
# Verifica IP Tor
killchain-hub → Fase 5 (Evasion Test)
```

### Docker Isolation
theHarvester gira in container Kali isolato:
- ✅ Nessuna traccia sul sistema host
- ✅ Dipendenze Python isolate
- ✅ Auto-cleanup dopo esecuzione

---

## 🛠️ Tool Inclusi

### Core & Recon Tools
| Tool | Fase | Descrizione |
|------|------|-------------|
| **theHarvester** | 1 | Email/subdomain harvesting (Docker Kali / Native) |
| **whois/dig** | 1 | DNS enumeration |
| **amass** | 1 / 7 | Subdomain enum / network mapping |
| **recon-ng** | 1 | Interactive OSINT framework |
| **SpiderFoot** | 1 | Web UI OSINT automation |
| **nmap** | 2 | Port scanning |
| **dnsrecon** | 2 | DNS reconnaissance |
| **nikto** | 2 | Web server scanner |
| **gospider** | 3 | Web crawler |
| **dirsearch** | 3 | Directory brute force |
| **gobuster** | 3 | Directory/DNS brute force |
| **hydra** | 4 | Password brute force (SMTP/HTTP) |

### Advanced Tools (Fase 7)
| Tool | Descrizione |
|------|-------------|
| **subfinder** | Subdomain enumeration passivo |
| **nuclei** | Vulnerability scanner con template |
| **sqlmap** | SQL injection automation |
| **ffuf** | Fast web fuzzer |
| **subfinder + nuclei** | Workflow chained: enum subdomains then scan them |

---

## 🐛 Troubleshooting

### Tor non si connette
```bash
# Verifica servizio Tor
sudo systemctl status tor

# Riavvia Tor
sudo systemctl restart tor

# Test connessione
torsocks curl ifconfig.me
```

### Docker permission denied
```bash
# Aggiungi user anon a gruppo docker
sudo usermod -aG docker anon

# Logout e login
exit
anon-mode
```

### Tool non trovato
```bash
# Reinstalla dipendenze
cd killchain-hub
sudo ./install.sh
```

### Logging non funziona
```bash
# Verifica lib/logger.sh
ls -la /usr/local/bin/lib/logger.sh

# Ricopia libreria
sudo cp lib/logger.sh /usr/local/bin/lib/
sudo chmod +x /usr/local/bin/lib/logger.sh
```

---

## ⚠️ Disclaimer

**Questo tool è per scopi educativi e test di penetrazione autorizzati solamente.**

- ✅ Usa solo su sistemi di tua proprietà o con autorizzazione scritta
- ✅ Rispetta le leggi locali sul computer crime
- ❌ L'autore non è responsabile per uso illegale o non etico

**Uso non autorizzato può violare:**
- Computer Fraud and Abuse Act (USA)
- Computer Misuse Act (UK)
- Direttiva NIS2 (EU)
- Leggi nazionali sul cybercrime

---

## 📄 Licenza

MIT License - vedi [LICENSE](LICENSE)

---

## 🤝 Contributi

Contributi benvenuti! Vedi [CONTRIBUTING.md](CONTRIBUTING.md)

### Roadmap
- [ ] Integrazione Metasploit
- [ ] Support per API REST
- [ ] Dashboard web real-time
- [ ] Export report in PDF
- [ ] Plugin system

---

## 📧 Contatti

- GitHub Issues: [Report bugs](https://github.com/tuo-username/killchain-hub/issues)
- Discussions: [Feature requests](https://github.com/tuo-username/killchain-hub/discussions)

---

**Made with ❤️ for ethical hackers and pentesters**