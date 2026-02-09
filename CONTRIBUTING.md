# Contributing to Killchain-Hub

Thank you for considering contributing to Killchain-Hub! This document provides guidelines for contributing to the project.

## 🤝 How to Contribute

### Reporting Bugs

Before creating bug reports, please check existing issues. When creating a bug report, include:

- **Description**: Clear description of the bug
- **Steps to Reproduce**: Detailed steps to reproduce the behavior
- **Expected Behavior**: What you expected to happen
- **Actual Behavior**: What actually happened
- **Environment**: OS, version, Docker version, etc.
- **Logs**: Relevant log files from `/home/anon/killchain_logs/`

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Use Case**: Why this enhancement would be useful
- **Proposed Solution**: How you envision the feature working
- **Alternatives**: Alternative solutions you've considered

### Pull Requests

1. **Fork the Repository**
   ```bash
   git clone https://github.com/your-username/killchain-hub.git
   cd killchain-hub
   ```

2. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**
   - Follow the coding style (see below)
   - Add tests if applicable
   - Update documentation

4. **Test Your Changes**
   ```bash
   # Run shellcheck on bash scripts
   shellcheck killchain-hub.sh install.sh anon-mode.sh lib/logger.sh
   
   # Test installation on fresh VM
   sudo ./install.sh
   
   # Test each phase
   anon-mode
   killchain-hub  # Test phases 1-8
   ```

5. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

   Use conventional commits:
   - `feat:` New feature
   - `fix:` Bug fix
   - `docs:` Documentation changes
   - `refactor:` Code refactoring
   - `test:` Adding tests
   - `chore:` Maintenance tasks

6. **Push and Create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   Then create a Pull Request on GitHub.

## 📝 Coding Style

### Bash Scripts

- Use `#!/bin/bash` shebang
- Use `set -e` for error handling
- Use meaningful variable names in UPPERCASE for globals
- Use lowercase for local variables
- Add comments for complex logic
- Use functions for reusable code
- Always quote variables: `"$VAR"` not `$VAR`

Example:
```bash
#!/bin/bash
set -e

# Global configuration
LOG_DIR="/var/log/killchain"

# Function to log messages
log_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_DIR/app.log"
}
```

### Python Scripts

- Follow PEP 8
- Use type hints
- Add docstrings to functions
- Use meaningful variable names

## 🔧 Adding New Tools

To add a new tool to Killchain-Hub:

1. **Update install.sh**
   ```bash
   # Add installation in appropriate section
   if ! command -v newtool &>/dev/null; then
       echo -e "${YELLOW}Installazione newtool...${NC}"
       # Installation commands
   fi
   ```

2. **Update killchain-hub.sh**
   ```bash
   # Add to appropriate phase or create new phase
   elif [ "$TOOL" = "X" ]; then
       log_info "Starting newtool scan"
       CMD="$PROXY newtool -options $TARGET -o ${LOGDIR}/newtool.txt"
   ```

3. **Update README.md**
   - Add tool to the tools table
   - Add usage example
   - Update requirements if needed

4. **Test the Integration**
   ```bash
   sudo ./install.sh
   anon-mode
   killchain-hub  # Test new tool
   ```

## 🧪 Testing

### Manual Testing Checklist

- [ ] Fresh installation on Debian 12
- [ ] Fresh installation on Ubuntu 22.04
- [ ] Fresh installation on Kali Linux
- [ ] All phases (1-8) execute without errors
- [ ] Logs are created properly
- [ ] Report generation works
- [ ] Tor routing functions correctly
- [ ] Docker theHarvester works
- [ ] All advanced tools install correctly

### Test Targets

Use these safe, legal test targets:
- `scanme.nmap.org` (Nmap's official test server)
- `testphp.vulnweb.com` (Acunetix test site)
- Your own domains/servers

**Never test on unauthorized targets!**

## 📚 Documentation

When adding features, update:

- `README.md` - User-facing documentation
- `CONTRIBUTING.md` - This file
- Inline code comments
- Function docstrings
- Example usage in comments

## 🔒 Security

### Reporting Security Issues

**Do not** open public issues for security vulnerabilities.

Instead, email: security@your-domain.com

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Security Best Practices

- Never commit credentials or API keys
- Use environment variables for sensitive data
- Validate all user inputs
- Use secure defaults
- Follow principle of least privilege

## 📋 Code Review Process

All submissions require review. We use GitHub pull requests for this purpose.

Reviewers will check:
- Code quality and style
- Test coverage
- Documentation updates
- Security implications
- Performance impact

## 🎯 Roadmap

Current priorities:

1. **High Priority**
   - Metasploit integration
   - REST API support
   - PDF report export

2. **Medium Priority**
   - Web dashboard
   - Plugin system
   - Database backend for results

3. **Low Priority**
   - Mobile app
   - Cloud deployment options

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## ❓ Questions?

- Open a GitHub Discussion
- Join our Discord: [link]
- Email: support@your-domain.com

---

**Thank you for contributing to Killchain-Hub! 🎯**
