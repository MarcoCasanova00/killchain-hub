# Push to GitHub - Instructions

## Initial Setup (First Time Only)

```bash
cd /path/to/killchain-hub

# Initialize git if not already done
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Killchain-Hub v5.0 with enhanced evasion"

# Create private repository on GitHub (via web interface or gh CLI)
# Then add remote:
git remote add origin https://github.com/YOUR_USERNAME/killchain-hub.git

# Push to GitHub
git push -u origin main
```

## Using GitHub CLI (Recommended)

```bash
# Install GitHub CLI if not installed
# On Debian/Ubuntu:
sudo apt install gh

# Authenticate
gh auth login

# Create private repository and push
cd /path/to/killchain-hub
git init
git add .
git commit -m "Initial commit: Killchain-Hub v5.0"
gh repo create killchain-hub --private --source=. --push
```

## Subsequent Updates

```bash
cd /path/to/killchain-hub

# Stage changes
git add .

# Commit with message
git commit -m "Update: Enhanced evasion features"

# Push to GitHub
git push
```

## Quick Commands from Windows

```powershell
# Navigate to repository
cd C:\Users\A797apulia\Desktop\killchain-hub

# Add all files
git add .

# Commit
git commit -m "Enhanced evasion and Google Cloud deployment guide"

# Push (you'll need to set up remote first)
git push origin main
```

## Setting Up Remote (If Not Done)

```bash
# Check current remotes
git remote -v

# Add GitHub remote (replace YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/killchain-hub.git

# Or use SSH (recommended)
git remote add origin git@github.com:YOUR_USERNAME/killchain-hub.git

# Verify
git remote -v
```

## .gitignore Recommendations

Create `.gitignore` to exclude sensitive files:

```
# Logs
*.log
killchain_logs/

# Temporary files
*.tmp
*.swp
*~

# User-specific config
.killchain-hub.conf

# Docker volumes
docker-volumes/

# Python
__pycache__/
*.pyc
*.pyo
venv/
.venv/

# OS files
.DS_Store
Thumbs.db
```
