# Installation Options - Killchain Hub v5.0

## Quick Install (Auto-detect)

```bash
git clone https://github.com/your-repo/killchain-hub.git
cd killchain-hub
chmod +x install.sh
sudo ./install.sh
```

The installer will automatically detect your OS and choose the best installation method.

---

## Installation Options

### 1. Kali Linux (Recommended)
**File:** `install_kali.sh`

**Features:**
- ✅ Native theHarvester (no Docker required)
- ✅ All tools from Kali repositories
- ✅ Optimized for pentesting
- ✅ Enhanced privacy configuration
- ✅ Pre-installed wordlists and templates

**Usage:**
```bash
sudo ./install_kali.sh
```

**Perfect for:**
- Kali Linux users
- Pentesting distributions
- Security labs
- VMs and containers

---

### 2. Debian/Ubuntu/Parrot
**File:** `install_debian.sh`

**Features:**
- ✅ Docker-based theHarvester isolation
- ✅ Full tool suite installation
- ✅ Tor configuration
- ✅ Multi-user setup

**Usage:**
```bash
sudo ./install_debian.sh
```

**Perfect for:**
- Standard Debian-based systems
- Ubuntu security setups
- Development environments

---

### 3. Arch Linux
**File:** `install_arch.sh`

**Features:**
- ✅ Native tools via AUR
- ✅ No Docker dependency
- ✅ Latest versions from repos
- ✅ Lightweight installation

**Usage:**
```bash
sudo ./install_arch.sh
```

**Perfect for:**
- Arch Linux users
- Rolling release systems
- Minimal installations

---

### 4. Portable (Minimal Linux)
**File:** `install_portable.sh`

**Features:**
- ✅ Binary releases only
- ✅ Works on minimal distros (Alpine, Tiny Core, etc.)
- ✅ User-local installation option
- ✅ Static builds where possible
- ✅ No root required (user install)

**Usage:**
```bash
./install_portable.sh  # User installation
sudo ./install_portable.sh  # System-wide
```

**Perfect for:**
- Minimal Linux ISOs
- Container environments
- Live USBs
- Embedded systems
- Air-gapped environments

---

## Configuration

### Docker vs Native Installation

The framework automatically detects whether to use Docker or native tools:

- **Kali Linux**: Always uses native theHarvester
- **Arch Linux**: Uses native tools (no Docker)
- **Debian/Ubuntu**: Uses Docker for theHarvester by default
- **Portable**: Uses native tools only

### Manual Configuration

Edit `.killchain-hub.conf` to customize:

```bash
# Force installation type
INSTALLATION_MODE="native"  # or "docker", "auto"

# Disable Docker completely
THEHARVESTER_DOCKER_IMAGE=""

# Force Tor usage
FORCE_TOR="yes"

# Enable portable mode
PORTABLE_MODE="true"
```

---

## Post-Installation

### Quick Start

```bash
# Switch to privacy user
anon-mode

# Verify installation
status-check

# Start framework
killchain-hub
```

### Tool Verification

```bash
# Check installed tools
which nmap gobuster nuclei subfinder theHarvester

# Test Tor
torsocks curl ifconfig.me

# Update nuclei templates
nuclei -update-templates
```

---

## System Requirements

### Minimal (Portable Mode)
- **RAM**: 512MB
- **Storage**: 2GB
- **OS**: Any Linux with glibc
- **Network**: Optional (for tool downloads)

### Standard (Kali/Debian/Arch)
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 10GB
- **OS**: Kali Linux, Debian 12+, Ubuntu 22.04+, Arch Linux
- **Network**: Required for installation

### Docker Mode (Debian/Ubuntu)
- **RAM**: 4GB minimum
- **Storage**: 15GB
- **Docker**: Latest version
- **Network**: Required

---

## Troubleshooting

### Installation Fails

1. **Permissions**: Run with sudo for system-wide install
2. **Network**: Check internet connection for tool downloads
3. **Dependencies**: Update package manager databases first
4. **Space**: Ensure sufficient disk space available

### Tools Not Found

```bash
# Re-run installation with verbose output
bash -x ./install_kali.sh 2>&1 | tee install.log

# Check tool paths
find /usr -name "*nmap*" 2>/dev/null
find $HOME -name "*nuclei*" 2>/dev/null
```

### Docker Issues

```bash
# Use Kali installer instead (no Docker)
sudo ./install_kali.sh

# Or force native mode in config
echo 'INSTALLATION_MODE="native"' >> ~/.killchain-hub.conf
```

---

## Migration

### From Docker to Native

If you previously used the Debian installer with Docker:

```bash
# Install native theHarvester
sudo apt install theharvester

# Update config
sed -i 's/THEHARVESTER_DOCKER_IMAGE=.*/THEHARVESTER_DOCKER_IMAGE=""/' ~/.killchain-hub.conf

# Test native installation
theHarvester -h
```

### From System to Portable

```bash
# Export current configs
cp /home/anon/.killchain-hub.conf ./

# Run portable installer
./install_portable.sh

# Restore configs
cp .killchain-hub.conf ~/.killchain-hub.conf
```

---

## Support

- **Kali Issues**: Use `install_kali.sh` for best compatibility
- **Minimal Systems**: Use `install_portable.sh` for universal compatibility  
- **Docker Problems**: Switch to native tools with Kali installer
- **Feature Requests**: GitHub Issues

Choose the installer that matches your use case for optimal performance and compatibility.