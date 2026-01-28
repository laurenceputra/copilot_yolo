# copilot_yolo

Run the GitHub Copilot CLI in a disposable Docker container with your current
repo mounted. The script builds a local image and starts Copilot with yolo mode.
Only the current directory is mounted into the container by default, so other
host paths are not visible unless you add additional mounts.

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

Pass-through arguments are forwarded to `copilot`:

```bash
copilot_yolo --help
```

By default, your current repo is mounted into the container at `/workspace`,
so make sure you run `copilot_yolo` from the repo you want Copilot to access.

## Automatic Updates

**copilot_yolo automatically ensures you're always using the latest GitHub Copilot CLI.**

Every time you run `copilot_yolo`, it:
1. Checks npm for the latest `@github/copilot` version
2. Compares it with the version in your local Docker image
3. Automatically rebuilds the image if a newer version is available

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

The container mounts `~/.config/github-copilot` from your host, so credentials
are shared between runs.

## Troubleshooting

- **Docker not found / daemon not running:** install Docker and start the Docker
  service, then re-run `copilot_yolo` (see Requirements above for links).
- **Files missing inside the container:** only the current directory is mounted
  by default. Run `copilot_yolo` from the repo you want to work on.

## Configuration

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
- `--pull` flag to force a pull when running `./.copilot_yolo.sh`
- Each run checks npm for the latest `@github/copilot` version (unless skipped)
  and rebuilds the image if it is out of date.
- Each run checks for copilot_yolo script updates (unless skipped with `COPILOT_SKIP_UPDATE_CHECK=1`)
  and auto-updates if a new version is available.

## Security note

The container mounts `~/.ssh` (read-only) and `~/.gitconfig` (read-only) to enable
Git operations with authentication. The container also has your GitHub Copilot
credentials mounted.

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

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## License

MIT License - see [LICENSE](LICENSE) file for details.