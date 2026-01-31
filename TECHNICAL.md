# Technical Documentation

This document provides technical details for developers contributing to or maintaining copilot_yolo.

---

## Architecture Overview

### Core Components

```
.copilot_yolo.sh              Main orchestration script
.copilot_yolo.Dockerfile      Container image definition
.copilot_yolo_entrypoint.sh   Container initialization
.copilot_yolo_config.sh       Configuration management module
.copilot_yolo_logging.sh      Logging utilities module
.copilot_yolo_completion.bash Bash shell completions
.copilot_yolo_completion.zsh  Zsh shell completions
install.sh                    Installation script
```

### Module Responsibilities

- **Main Script** (`.copilot_yolo.sh`): Handles auto-updates, argument parsing, Docker operations, version checks
- **Configuration Module** (`.copilot_yolo_config.sh`): Loads config files, generates sample configs
- **Entrypoint** (`.copilot_yolo_entrypoint.sh`): Container user setup, permission management, cleanup

---

## Auto-Update Mechanism

### Design Philosophy

The auto-update system uses a **three-phase download strategy** to ensure backward and forward compatibility.

### Implementation (`.copilot_yolo.sh`, lines 72-95)

#### Phase 1: Core Files (Required)
```bash
if curl -fsSL ... .copilot_yolo.sh && \
   curl -fsSL ... .copilot_yolo.Dockerfile && \
   curl -fsSL ... .copilot_yolo_entrypoint.sh && \
   curl -fsSL ... VERSION; then
```

These files must download successfully or the update fails.

#### Phase 2: Module Files (Optional, Non-Fatal)
```bash
# Download optional/new files (non-fatal if they don't exist)
curl -fsSL ... .dockerignore 2>/dev/null || true
curl -fsSL ... .copilot_yolo_config.sh 2>/dev/null || true
curl -fsSL ... .copilot_yolo_logging.sh 2>/dev/null || true
curl -fsSL ... .copilot_yolo_completion.bash 2>/dev/null || true
curl -fsSL ... .copilot_yolo_completion.zsh 2>/dev/null || true
```

- `2>/dev/null` suppresses 404 errors
- `|| true` ensures the script continues even if downloads fail
- Allows updates from older versions that don't have these files

#### Phase 3: Conditional Copying
```bash
[[ -f "${temp_dir}/.copilot_yolo_config.sh" ]] && cp ...
[[ -f "${temp_dir}/.copilot_yolo_logging.sh" ]] && cp ...
[[ -f "${temp_dir}/.copilot_yolo_completion.bash" ]] && cp ...
[[ -f "${temp_dir}/.copilot_yolo_completion.zsh" ]] && cp ...
```

Only copies files that successfully downloaded.

### Compatibility Guarantees

- **Backward Compatible**: v1.0.3 → v1.1.0 downloads all new modules
- **Forward Compatible**: v1.1.0 → v1.0.3 gracefully handles missing files (404s ignored)
- **Future-Proof**: New modules can be added without breaking older versions

---

## Configuration System

### Config File Location

The configuration file is always located in the installation directory:
- `~/.copilot_yolo/.copilot_yolo.conf` (default installation)
- `$COPILOT_YOLO_DIR/.copilot_yolo.conf` (custom installation directory)

### Config Loading Logic

The `load_config()` function in `.copilot_yolo_config.sh`:
- Checks for config file in installation directory
- Sources the file if it exists
- Returns 0 if config loaded, 1 if no config found
- Main script gracefully handles missing config (optional feature)

### Adding New Configuration Options

1. Add variable with default in `.copilot_yolo.sh`
2. Document in sample config template (`.copilot_yolo_config.sh`)
3. Update README.md configuration section
4. Update CHANGELOG.md

---

## Docker Image Build Process

### Version Tracking

The Docker image embeds two version identifiers:

```dockerfile
# Record installed Copilot CLI version
RUN node -e "..." > /opt/copilot-version

# Record copilot_yolo version
RUN printf '%s' "${COPILOT_YOLO_VERSION}" > /opt/copilot-yolo-version
```

These enable version comparison for auto-rebuild decisions.

### Build Arguments

- `BASE_IMAGE` - Node.js base image (default: `node:20-slim`)
- `COPILOT_VERSION` - GitHub Copilot CLI version to install
- `COPILOT_YOLO_VERSION` - copilot_yolo script version

### Rebuild Triggers

Image rebuilds when:
1. Copilot CLI version changes (detected via npm registry check)
2. copilot_yolo VERSION file changes
3. User requests rebuild (`--pull` flag or `COPILOT_BUILD_NO_CACHE=1`)

---

## Argument Parsing

### Design Pattern

Uses a `case` statement for maintainability:

```bash
case "${arg}" in
  --pull)
    PULL_REQUESTED=1
    ;;
  health|--health)
    run_health_check=1
    ;;
  config|--generate-config)
    generate_config=1
    ;;
  *)
    pass_args+=("${arg}")
    ;;
esac
```

### Special Commands

- `health` / `--health` - Run diagnostics (handled before Docker)
- `config` / `--generate-config` - Generate config file (handled before Docker)
- `login` - Pass to copilot without `--yolo` flag
- All other args passed to `copilot --yolo`

---

## Testing Approach

### Manual Testing

```bash
# Test health check
COPILOT_SKIP_UPDATE_CHECK=1 ./copilot_yolo.sh health

# Test config generation
COPILOT_SKIP_UPDATE_CHECK=1 ./copilot_yolo.sh config

# Test dry run
COPILOT_DRY_RUN=1 ./copilot_yolo.sh
```

### CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/ci.yml`) validates:

1. **ShellCheck Linting** - Code quality for all shell scripts
2. **Docker Build Test** - Validates image builds successfully
3. **Install Script Test** - Tests installation on Ubuntu and macOS
4. **Health Check Test** - Verifies diagnostic command works
5. **Config Generation Test** - Validates config file creation
6. **VERSION Validation** - Ensures semver format

### Adding New Tests

1. Add test job to `.github/workflows/ci.yml`
2. Use descriptive job name
3. Include verification steps with clear output
4. Ensure tests are idempotent

---

## Performance Optimizations

### Conditional Cleanup

The entrypoint script (`.copilot_yolo_entrypoint.sh`) only performs cleanup when needed:

```bash
check_workspace_ownership() {
  if [ -d /workspace ]; then
    if [ -n "$(find /workspace \( ! -uid "${TARGET_UID}" -o ! -gid "${TARGET_GID}" \) -print -quit 2>/dev/null)" ]; then
      workspace_changed=1
    fi
  fi
}
```

Only runs expensive `chown -R` if files have wrong ownership.

### Version Check Optimization

```bash
if [[ "${COPILOT_SKIP_VERSION_CHECK:-0}" != "1" ]]; then
  # Only check npm when needed
fi
```

Users can skip version checks for faster execution with `COPILOT_SKIP_VERSION_CHECK=1`.

---

## Error Handling

### Design Principles

1. **Fail Fast for Critical Errors**: Docker not installed, daemon not running
2. **Graceful Degradation**: Missing optional modules don't break core functionality
3. **Actionable Messages**: Error messages include next steps and links
4. **Platform-Specific Guidance**: Installation instructions vary by OS

### Example Error Handling

```bash
if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not on PATH."
  echo "${install_hint}"  # Platform-specific instructions
  exit 127
fi
```

---

## Security Considerations

### Mounted Paths

**Mounted** (Read-Write):
- Current directory → `/workspace`
- `~/.copilot` → Container home (credentials)
- `~/.config/gh` → Container home (gh CLI auth)

**Mounted** (Read-Only):
- `~/.gitconfig` → Container home (git config)

**NOT Mounted**:
- `~/.ssh` - SSH keys excluded to reduce security blast radius

### Sudo in Container

The entrypoint grants passwordless sudo to the mapped user:

```bash
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${TARGET_USER}" > /etc/sudoers.d/90-copilot
```

This allows system package installation within the container. The cleanup hook ensures file ownership is restored on exit.

---

## Adding New Features

### Checklist

1. **Code Changes**
   - Implement feature in appropriate module
   - Follow existing code patterns
   - Add error handling

2. **Configuration**
   - Add environment variables if needed
   - Update sample config template
   - Document precedence/defaults

3. **Testing**
   - Add CI test if applicable
   - Manual testing with various scenarios
   - Test backward compatibility

4. **Documentation**
   - Update README.md (user-facing)
   - Update TECHNICAL.md (this file)
   - Update CHANGELOG.md
   - Update CONTRIBUTING.md if needed

5. **Version**
   - Bump VERSION file following semver
   - Update CHANGELOG.md with changes
   - Tag release when merged

---

## Development Workflow

### Local Development

```bash
# Clone repository
git clone https://github.com/laurenceputra/copilot_yolo.git
cd copilot_yolo

# Make changes to scripts
vim .copilot_yolo.sh

# Test locally
COPILOT_SKIP_UPDATE_CHECK=1 ./.copilot_yolo.sh health

# Check shell syntax
bash -n .copilot_yolo.sh
shellcheck .copilot_yolo.sh
```

### Release Process

1. Update VERSION file (semver: MAJOR.MINOR.PATCH)
2. Update CHANGELOG.md with changes
3. Commit changes: `git commit -m "Release vX.Y.Z"`
4. Tag release: `git tag vX.Y.Z`
5. Push: `git push origin main --tags`

The auto-update mechanism will pull new versions automatically.

---

## Module File Structure

### Configuration Module (`.copilot_yolo_config.sh`)

```bash
#!/usr/bin/env bash
# Configuration file support for copilot_yolo

COPILOT_CONFIG_FILES=(...)  # Priority list

load_config() {
  # Find and source first available config
}

generate_sample_config() {
  # Create template config file
}
```

---

## Debugging

### Enable Verbose Output

```bash
# Bash trace mode
bash -x .copilot_yolo.sh

# Debug logging
export COPILOT_LOG_LEVEL=0
export COPILOT_LOG_FILE=/tmp/copilot_debug.log
./copilot_yolo.sh
tail -f /tmp/copilot_debug.log
```

### Common Issues

**Issue**: Auto-update fails  
**Debug**: Check curl output, verify network connectivity, test URL manually

**Issue**: Config not loaded  
**Debug**: Verify config file exists and has correct permissions, check syntax

**Issue**: Docker build fails  
**Debug**: Run with `COPILOT_BUILD_NO_CACHE=1`, check Docker logs

---

## Code Style Guidelines

### Shell Script Conventions

- Use `#!/usr/bin/env bash` shebang
- Enable strict mode: `set -euo pipefail`
- Quote all variables: `"${VAR}"`
- Use `[[ ]]` for tests, not `[ ]`
- Use `$(command)` not backticks
- Check shellcheck for linting

### Function Naming

- Use lowercase with underscores: `load_config`
- Descriptive names: `check_workspace_ownership`
- Internal functions start with underscore: `_internal_helper`

### Comments

- Document complex logic
- Explain non-obvious decisions
- Include examples for tricky patterns
- Don't comment obvious code

---

## Future Development Opportunities

### Potential Enhancements

1. **Telemetry** (opt-out) - Understand usage patterns
2. **Interactive Setup Wizard** - Improve first-time experience
3. **Performance Benchmarking** - Track and optimize speed
4. **Security Scanning** - Integrate vulnerability checks in CI
5. **Pre-commit Hooks** - Automate code quality checks
6. **Multi-container Support** - Allow service dependencies

### Architecture Improvements

1. **Plugin System** - Allow extensions without core changes
2. **API Layer** - Separate CLI from core logic
3. **Configuration Schema** - Validate config files
4. **State Management** - Track container/image state

---

## Getting Help

- **Issues**: https://github.com/laurenceputra/copilot_yolo/issues
- **Contributing**: See CONTRIBUTING.md
- **Documentation**: See README.md for user guide

---

## Maintenance Notes

### Regular Tasks

- Monitor GitHub issues for bug reports
- Keep dependencies updated (Node.js version, Copilot CLI)
- Review and merge pull requests
- Update documentation as features evolve
- Test on new OS versions periodically

### Breaking Change Policy

- Avoid breaking changes when possible
- If necessary, document in CHANGELOG with migration guide
- Provide deprecation warnings for one version before removal
- Maintain backward compatibility for at least one major version
