# copilot_yolo

Run the GitHub Copilot CLI in a disposable Docker container with your current
repo mounted. The script builds a local image and starts Copilot with yolo mode,
including GitHub CLI (`gh`), ripgrep (`rg`), and the OpenSSH client for PR workflows.
Only the current directory is mounted into the container by default, so other
host paths are not visible unless you add additional mounts.

## ✨ What's New in v1.1.0

Version 1.1.0 adds powerful new capabilities while maintaining 100% backward compatibility:

- 🏥 **Health Check**: Diagnose system setup with `copilot_yolo health`
- ⚙️ **Configuration Files**: Persistent settings via `copilot_yolo config`
- 🔧 **Shell Completions**: Tab completion for bash and zsh (auto-installed)
- 📝 **Structured Logging**: Configurable log levels and file output
- ✅ **CI/CD Pipeline**: Automated testing on every change
- 🎯 **Better Error Messages**: Platform-specific guidance and actionable steps
- 📦 **Modular Architecture**: Cleaner code organization for easier maintenance

See [CHANGELOG.md](CHANGELOG.md) for complete details.

## Requirements

- Docker (Desktop or Engine)
- Bash (macOS/Linux; Windows via WSL recommended)
- Docker Buildx (recommended for reliable builds): https://docs.docker.com/build/buildx/

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/laurenceputra/copilot_yolo/main/install.sh | bash
```

By default this installs into `~/.copilot_yolo` and sources it from your shell
profile. You can override paths:

```bash
COPILOT_YOLO_DIR="$HOME/.copilot_yolo" \
COPILOT_YOLO_PROFILE="$HOME/.zshrc" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/laurenceputra/copilot_yolo/main/install.sh)"
```

## Quick start

```bash
copilot_yolo
```

### Health Check

Check your system setup and copilot_yolo installation:

```bash
copilot_yolo health
```

This will verify:
- Docker installation and daemon status
- Docker Buildx availability
- copilot_yolo version
- Docker image status
- Available mounted paths

Pass-through arguments are forwarded to `copilot`:

```bash
copilot_yolo --help
```

By default, your current repo is mounted into the container at `/workspace`,
so make sure you run `copilot_yolo` from the repo you want Copilot to access.

All unrecognized command-line arguments are passed through to the Copilot CLI:
- Default behavior: `copilot_yolo [args...]` runs `copilot --yolo [args...]`
- Special case: `copilot_yolo login [args...]` runs `copilot login [args...]` (without `--yolo`)

## Command Behavior Reference

`copilot_yolo` handles a small set of wrapper commands/flags itself, then passes
all remaining arguments to `copilot`.

### Wrapper-only commands (handled before Docker run)

- `health` / `--health`: run diagnostics and exit
- `config` / `--generate-config`: generate a sample config file and exit

### Wrapper-only flags (affect wrapper behavior, not Copilot subcommands)

- `--pull`: force rebuild path and enable base image pull during build
- `--mount-ssh`: mount `~/.ssh` read-only into the container (if present)

### Pass-through behavior

- Any argument that is not recognized by the wrapper is forwarded to `copilot`
- `--yolo` is added automatically unless the first forwarded argument is `login`

Examples:

```bash
# Forwarded as: copilot --yolo --help
copilot_yolo --help

# Forwarded as: copilot login
copilot_yolo login

# Wrapper handles --pull; Copilot receives: copilot --yolo explain README.md
copilot_yolo --pull explain README.md
```

## What Gets Mounted

The container automatically mounts the following paths from your host system:

| Host Path | Container Path | Mode | Purpose |
|-----------|---------------|------|---------|
| Current directory (`$(pwd)`) | `/workspace` | Read-write | Your working repository/project files |
| `~/.copilot` | `/home/copilot/.copilot` | Read-write | Copilot CLI configuration and credentials (if directory exists) |
| `~/.config/gh` | `/home/copilot/.config/gh` | Read-write | GitHub CLI authentication (if directory exists; uses `XDG_CONFIG_HOME` when set) |
| `~/.gitconfig` | `/home/copilot/.gitconfig` | Read-only | Git configuration for authentication (if file exists) |
| `~/.ssh` (optional) | `/home/copilot/.ssh` | Read-only | SSH keys for Git operations (requires `--mount-ssh` flag) |

**Notes:**
- The working directory mount is always at `/workspace` by default (configurable via `COPILOT_YOLO_WORKDIR`)
- Only files within the current directory are visible to the container
- Git config is mounted read-only for security
- Copilot configuration is shared between runs via `~/.copilot`
- GitHub CLI config is shared from `~/.config/gh` (or `$XDG_CONFIG_HOME/gh`)
- All file modifications in `/workspace` are immediately reflected on your host system
- SSH keys are NOT mounted by default to reduce security blast radius
- Use `--mount-ssh` flag to enable SSH key mounting when you need Git operations via SSH
- The container includes the OpenSSH client; you only need to mount keys when required

## Automatic Updates

**copilot_yolo automatically ensures you're always using the latest GitHub Copilot CLI.**

Every time you run `copilot_yolo`, it:
1. Checks npm for the latest `@github/copilot` version
2. Compares it with the version in your local Docker image
3. Automatically rebuilds the image if a newer version is available
4. Rebuilds the image if the local `copilot_yolo` VERSION changes

This means you always get the latest features and fixes without manual intervention.

To skip version checking (use existing image):
```bash
COPILOT_SKIP_VERSION_CHECK=1 copilot_yolo
```

To force a rebuild (even if versions match):
```bash
COPILOT_BUILD_NO_CACHE=1 copilot_yolo
# or
copilot_yolo --pull
```

## Login

The first run will prompt you to sign in. You can also log in explicitly:

```bash
copilot_yolo login
```

For headless or remote environments, use device auth or other login methods:

```bash
copilot_yolo login --help
```

The container mounts `~/.copilot` (if it exists) from your host, so credentials 
are shared between runs.
If `GH_TOKEN` or `GITHUB_TOKEN` is set on your host, copilot_yolo passes it into
the container so `gh` can authenticate without an interactive login.

## Shell Completions

Shell completions for bash and zsh are automatically installed and loaded. After installation, you can:

- Type `copilot_yolo` and press Tab to see available commands
- Get file path completions for commands like `explain`, `review`, `test`, `describe`

To manually load completions in your current shell:
```bash
# Bash
source ~/.copilot_yolo/.copilot_yolo_completion.bash

# Zsh
source ~/.copilot_yolo/.copilot_yolo_completion.zsh
```

## Configuration

Generate a sample configuration file:

```bash
copilot_yolo config
# Creates ~/.copilot_yolo/.copilot_yolo.conf
```

The configuration file is always located in the installation directory at `~/.copilot_yolo/.copilot_yolo.conf` (or `$COPILOT_YOLO_DIR/.copilot_yolo.conf` if you specified a custom installation directory).

The configuration file is sourced as a bash script before the wrapper computes
its defaults. You can use normal shell syntax (variables, conditionals, helper
functions) to define settings.

Edit the configuration file to customize:
- Docker image settings (`COPILOT_BASE_IMAGE`, `COPILOT_YOLO_IMAGE`)
- Build behavior (`COPILOT_BUILD_NO_CACHE`, `COPILOT_BUILD_PULL`)
- Version checks (`COPILOT_SKIP_VERSION_CHECK`, `COPILOT_SKIP_UPDATE_CHECK`)
- Repository update source (`COPILOT_YOLO_REPO`, `COPILOT_YOLO_BRANCH`)
- Container paths (`COPILOT_YOLO_HOME`, `COPILOT_YOLO_WORKDIR`)
- Cleanup behavior (`COPILOT_YOLO_CLEANUP`)

### Configuration and environment interaction

Configuration values are resolved in this sequence:

1. Start with values from your current shell environment
2. Source `~/.copilot_yolo/.copilot_yolo.conf` (or `$COPILOT_YOLO_DIR/.copilot_yolo.conf`)
3. Apply built-in defaults for variables that remain unset/empty

Because step 2 sources a bash script, assignment style in the config file
controls precedence:
- Direct assignment (for example `COPILOT_BASE_IMAGE="node:22-slim"`) overrides shell env values
- Conditional assignment (for example `: "${COPILOT_BASE_IMAGE:=node:22-slim}"`) keeps shell env overrides

Example config patterns:

```bash
# Fixed value (overrides the environment if set later in this file)
COPILOT_BASE_IMAGE="node:22-slim"

# Allow shell/session override:
# COPILOT_BASE_IMAGE=node:20-slim copilot_yolo
: "${COPILOT_BASE_IMAGE:=node:22-slim}"

# Skip update checks by default in this installation
COPILOT_SKIP_UPDATE_CHECK="1"
```

### Environment variables (wrapper/build configuration)

- `COPILOT_BASE_IMAGE` (default: `node:20-slim`)
- `COPILOT_YOLO_IMAGE` (default: `copilot-cli-yolo:local`; only be set to images you trust)
- `COPILOT_YOLO_HOME` (default: `/home/copilot`; advanced, must be an absolute container path)
- `COPILOT_YOLO_WORKDIR` (default: `/workspace`; advanced, must be an absolute container path)
- `COPILOT_YOLO_CLEANUP` (default: `1`) to chown `/workspace` to your UID on exit; set to `0` to skip
- `COPILOT_YOLO_REPO` (default: `laurenceputra/copilot_yolo`) to specify a different repository for updates
- `COPILOT_YOLO_BRANCH` (default: `main`) to specify a different branch for updates
- `COPILOT_SKIP_UPDATE_CHECK=1` to skip automatic update checks
- `COPILOT_BUILD_NO_CACHE=1` to build without cache
- `COPILOT_BUILD_PULL=1` to pull the base image during build
- `COPILOT_SKIP_VERSION_CHECK=1` to skip npm version checks and reuse an existing image; requires that the image already exists (for example from a previous run), otherwise the script may fail instead of building it
- `COPILOT_DRY_RUN=1` to print the computed docker build/run commands without executing

### Wrapper-only CLI flags and commands

- `--pull` to force a rebuild path and base image pull
- `--mount-ssh` to mount `~/.ssh` directory (read-only) for Git operations via SSH
- `health` / `--health` to run system diagnostics
- `config` / `--generate-config` to generate a sample configuration file

**Auto-update behavior:**
- Each run checks npm for the latest `@github/copilot` version (unless skipped)
  and rebuilds the image if it is out of date.
- The image also rebuilds when the local `copilot_yolo` VERSION changes.
- Each run checks for copilot_yolo script updates (unless skipped with `COPILOT_SKIP_UPDATE_CHECK=1`)
  and auto-updates if a new version is available.

## Troubleshooting

- **Run health check first:** `copilot_yolo health` will diagnose common issues
- **Docker not found / daemon not running:** install Docker and start the Docker
  service, then re-run `copilot_yolo` (see Requirements above for links).
- **Files missing inside the container:** only the current directory is mounted
  by default. Run `copilot_yolo` from the repo you want to work on.
- **For developers:** See [TECHNICAL.md](TECHNICAL.md) for architecture details and debugging guidance.

## Security note

The container mounts `~/.gitconfig` (read-only) to enable Git operations with 
authentication. The container also mounts `~/.copilot` (if it exists) so your 
GitHub Copilot CLI configuration and credentials are available.

**Important:** SSH keys (`~/.ssh`) are NOT mounted by default to reduce the 
security blast radius. If you need SSH access for Git operations (e.g., to allow 
agents to git push), you can use the `--mount-ssh` flag:

```bash
copilot_yolo --mount-ssh
```

**Security Warning:** When using `--mount-ssh`, ensure you have proper branch 
protection rules configured in your repositories to prevent accidental or 
unauthorized pushes to critical branches (main, master, production, etc.).

Alternatively, consider using HTTPS with credential helpers or Git credential 
manager instead of SSH keys.

The container enables passwordless `sudo` for the mapped user to allow system
installs. Use with care; `sudo` writes into `/workspace` have their ownership
restored via a chown on exit (but file content and modifications are not undone),
and they still run as root inside the container.

## Update

Update the wrapper scripts by re-running the installer (it overwrites the
files inside `COPILOT_YOLO_DIR`):

```bash
curl -fsSL https://raw.githubusercontent.com/laurenceputra/copilot_yolo/main/install.sh | bash
```

If you installed from a fork or branch, pass those again:

```bash
COPILOT_YOLO_REPO="yourname/copilot_yolo" \
COPILOT_YOLO_BRANCH="main" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yourname/copilot_yolo/main/install.sh)"
```

The GitHub Copilot CLI image updates automatically when you run `copilot_yolo`.
To force a rebuild or pull:

```bash
COPILOT_BUILD_NO_CACHE=1 copilot_yolo
# or
copilot_yolo --pull
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines and [TECHNICAL.md](TECHNICAL.md) for architecture and implementation details.

## License

MIT License - see [LICENSE](LICENSE) file for details.
