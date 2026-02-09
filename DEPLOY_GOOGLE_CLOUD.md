# Killchain-Hub: Google Cloud Debian Deployment Guide

## Quick Deploy to Google Cloud VM

This guide shows how to transform a fresh Debian Bookworm VM on Google Cloud into a lightweight penetration testing machine without installing full Kali Linux.

---

## 🚀 One-Command Deploy

```bash
# SSH into your Google Cloud VM, then run:
curl -sSL https://raw.githubusercontent.com/your-repo/killchain-hub/main/install.sh | sudo bash
```

Or manual installation:

```bash
# Clone repository
git clone https://github.com/your-repo/killchain-hub.git
cd killchain-hub

# Run installer
sudo ./install.sh

# Switch to anon user
anon-mode

# Start using
killchain-hub
```

---

## 📋 Architecture: Hybrid Native + Docker

### Native Tools (Fast, Direct)
These run directly on Debian without Docker overhead:

| Tool | Why Native | Installation |
|------|-----------|--------------|
| **nmap** | Best performance for port scanning | apt install |
| **gobuster** | Fast directory brute force | apt install |
| **hydra** | CPU-intensive brute forcing | apt install |
| **nikto** | Perl-based, works well on Debian | apt install |
| **dnsrecon** | Python tool, simple deps | apt install |
| **subfinder** | Go binary, no dependencies | go install |
| **nuclei** | Go binary, self-contained | go install |
| **ffuf** | Go binary, lightweight | go install |
| **amass** | Go binary, network mapping | go install |
| **dirsearch** | Python, via pip | pip install |
| **sqlmap** | Python, via pip | pip install |

### Docker Tools (Isolated, Complex Dependencies)
These run in Kali Docker containers to avoid dependency hell:

| Tool | Why Docker | Container |
|------|-----------|-----------|
| **theHarvester** | Python 3.12+ deps conflict with Debian | kalilinux/kali-rolling |

---

## 🔧 Google Cloud VM Setup

### Recommended VM Configuration

```bash
# Create VM with gcloud CLI
gcloud compute instances create killchain-hub \
    --zone=us-central1-a \
    --machine-type=e2-medium \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --boot-disk-size=20GB \
    --boot-disk-type=pd-standard \
    --tags=pentest
```

**Minimum Specs**:
- **CPU**: 2 vCPUs (e2-medium)
- **RAM**: 4GB
- **Disk**: 20GB
- **OS**: Debian 12 (Bookworm)

### Firewall Rules

```bash
# Allow SSH (if not already allowed)
gcloud compute firewall-rules create allow-ssh \
    --allow tcp:22 \
    --target-tags pentest

# Optional: Allow outbound Tor traffic
gcloud compute firewall-rules create allow-tor \
    --allow tcp:9050,tcp:9051 \
    --target-tags pentest \
    --direction EGRESS
```

---

## 📦 Installation Process

The `install.sh` script does the following:

### 1. System Update
```bash
apt update && apt upgrade -y
```

### 2. Core Dependencies
```bash
# Native tools
apt install -y docker.io torsocks tor nmap gobuster hydra nikto dnsrecon

# Build tools for Go
apt install -y golang-go build-essential

# Python environment
apt install -y python3 python3-pip python3-venv
```

### 3. Go-Based Tools
```bash
# Installed to /usr/local/bin
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/ffuf/ffuf/v2@latest
go install github.com/owasp-amass/amass/v4/...@master
```

### 4. Python Tools
```bash
pip3 install -r requirements.txt --break-system-packages
# Includes: dirsearch, sqlmap, impacket, requests, etc.
```

### 5. Docker Setup
```bash
# Enable Docker service
systemctl enable --now docker

# Add anon user to docker group
usermod -aG docker anon
```

### 6. Tor Configuration
```bash
# Start Tor service
systemctl enable --now tor

# Configure torsocks
cat > /etc/torsocks.conf << EOF
server = 127.0.0.1
server_port = 9050
server_type = 5
EOF
```

---

## 🐳 Docker Strategy

### Why Hybrid Approach?

**Native Benefits**:
- ✅ Faster execution (no container overhead)
- ✅ Direct network access
- ✅ Lower memory usage
- ✅ Simpler debugging

**Docker Benefits**:
- ✅ Isolated dependencies
- ✅ No system pollution
- ✅ Easy cleanup
- ✅ Reproducible environment

### Current Docker Usage

Only **theHarvester** uses Docker because:
1. Requires Python 3.12+ (Debian 12 has Python 3.11)
2. Has complex dependency tree
3. Conflicts with system Python packages

```bash
# How it works:
docker run --rm -u root -v /logs:/logs kalilinux/kali-rolling bash -lc \
  'apt update && apt install -yq theharvester && theHarvester ...'
```

### Adding More Docker Tools (If Needed)

If you encounter dependency issues with other tools, you can dockerize them:

```bash
# Example: Running wpscan in Docker
docker run --rm -v /logs:/logs kalilinux/kali-rolling bash -c \
  'apt update && apt install -yq wpscan && wpscan --url $TARGET'
```

---

## 🔒 Security Considerations for Cloud VMs

### 1. Firewall Configuration
```bash
# Only allow SSH from your IP
gcloud compute firewall-rules update allow-ssh \
    --source-ranges=YOUR_IP/32
```

### 2. SSH Key Authentication
```bash
# Disable password authentication
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### 3. Automatic Updates
```bash
# Enable unattended upgrades
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 4. Tor Anonymity
```bash
# Verify Tor is working
torsocks curl ifconfig.me

# Should show different IP than:
curl ifconfig.me
```

---

## 💰 Cost Optimization

### Google Cloud Pricing (us-central1)

| VM Type | vCPUs | RAM | Cost/Month | Use Case |
|---------|-------|-----|------------|----------|
| e2-micro | 2 | 1GB | ~$7 | Testing only |
| e2-small | 2 | 2GB | ~$14 | Light scans |
| **e2-medium** | 2 | 4GB | **~$27** | **Recommended** |
| e2-standard-2 | 2 | 8GB | ~$49 | Heavy workloads |

### Cost Saving Tips

1. **Use Preemptible VMs** (up to 80% cheaper)
   ```bash
   gcloud compute instances create killchain-hub \
       --preemptible \
       --machine-type=e2-medium
   ```

2. **Stop VM when not in use**
   ```bash
   gcloud compute instances stop killchain-hub
   ```

3. **Use Spot VMs** (newer, more reliable than preemptible)
   ```bash
   gcloud compute instances create killchain-hub \
       --provisioning-model=SPOT \
       --machine-type=e2-medium
   ```

---

## 🧪 Post-Installation Testing

```bash
# 1. SSH into VM
gcloud compute ssh killchain-hub

# 2. Verify installation
which killchain-hub
which subfinder
which nuclei
docker --version

# 3. Test Tor
torsocks curl ifconfig.me

# 4. Switch to anon user
anon-mode

# 5. Run evasion test
killchain-hub
# Select Phase 5 (Evasion Test)

# 6. Test Docker theHarvester
killchain-hub
# Select Phase 1 → Tool 1 (theHarvester)
# Target: scanme.nmap.org
```

---

## 📊 Performance Benchmarks

On **e2-medium** (2 vCPU, 4GB RAM):

| Tool | Target | Time | Notes |
|------|--------|------|-------|
| nmap | /24 subnet | ~5 min | Fast port scan |
| theHarvester | domain | ~2 min | Docker overhead |
| subfinder | domain | ~30 sec | Native Go speed |
| nuclei | single URL | ~1 min | Template-based |
| dirsearch | website | ~3 min | 10k wordlist |

---

## 🔄 Updating the Tool

```bash
cd killchain-hub
git pull
sudo ./install.sh  # Reinstall with updates
```

---

## 🐛 Troubleshooting

### Docker Permission Denied
```bash
# Add current user to docker group
sudo usermod -aG docker $USER
# Logout and login again
exit
gcloud compute ssh killchain-hub
```

### Tor Not Working
```bash
# Check Tor status
sudo systemctl status tor

# Restart Tor
sudo systemctl restart tor

# Test connection
torsocks curl ifconfig.me
```

### Go Tools Not Found
```bash
# Add Go bin to PATH
echo 'export PATH=$PATH:/root/go/bin' >> ~/.bashrc
source ~/.bashrc
```

### Out of Disk Space
```bash
# Clean Docker images
docker system prune -a

# Clean apt cache
sudo apt clean
```

---

## 📝 Example Workflow

```bash
# 1. Deploy VM
gcloud compute instances create pentest-vm \
    --machine-type=e2-medium \
    --image-family=debian-12

# 2. SSH and install
gcloud compute ssh pentest-vm
git clone https://github.com/your-repo/killchain-hub.git
cd killchain-hub
sudo ./install.sh

# 3. Start pentesting
anon-mode
killchain-hub

# 4. Run full auto scan
# Phase 6 → Target: example.com

# 5. Generate report
# Phase 8

# 6. Download results
exit
gcloud compute scp pentest-vm:/home/anon/killchain_logs/* ./results/ --recurse

# 7. Stop VM to save costs
gcloud compute instances stop pentest-vm
```

---

**Your Debian VM is now a lightweight Kali alternative! 🎯**
