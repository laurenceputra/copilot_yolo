# copilot_yolo

A command-line tool that runs the latest GitHub Copilot CLI in Docker with Yolo mode, automatically mounting necessary directories and maintaining user permissions with sudo access.

## Features

- 🐳 Runs the latest `copilot-cli` in Docker (no local installation needed)
- 🔐 Mounts Git config and SSH keys for authentication
- 💾 Mounts GitHub Copilot credentials directory
- 📁 Mounts your current working directory as the workspace
- 👤 Maintains your user ID and group ID in the container
- 🔑 Provides sudo access within the container for installing packages
- 🚀 Runs copilot in Yolo mode automatically

## Prerequisites

- Docker installed and running
- Python 3.6 or higher (for installation)

## Installation

### From Source

```bash
git clone https://github.com/laurenceputra/copilot_yolo.git
cd copilot_yolo
pip install -e .
```

### Using pip (once published)

```bash
pip install copilot_yolo
```

## Usage

### Basic Usage

Simply run `copilot_yolo` in any directory where you want to use GitHub Copilot:

```bash
cd /path/to/your/project
copilot_yolo
```

This will:
1. Build a custom Docker image (first run only)
2. Mount your current directory to `/workspace` in the container
3. Mount your Git config, SSH keys, and Copilot credentials
4. Create a user in the container with your UID/GID
5. Give the user sudo access (no password required)
6. Run `copilot --yolo` on your workspace

### Options

```bash
# Specify a different workspace directory
copilot_yolo --workspace /path/to/project

# Force rebuild of the Docker image (to get latest copilot-cli)
copilot_yolo --rebuild

# Pass additional arguments to copilot
copilot_yolo -- --help
```

### Using Sudo in the Container

The container is set up with a user matching your UID/GID that has passwordless sudo access. This allows you to install packages or perform other administrative tasks:

```bash
# From within copilot_yolo, if you need to install something:
sudo apt-get update && sudo apt-get install -y <package>
```

## How It Works

The tool:
1. Builds a custom Docker image based on the official `copilot-cli` image
2. Adds sudo support and a custom entrypoint script
3. Creates a Docker container that:
   - Uses your current working directory as `/workspace`
   - Mounts `~/.gitconfig` for Git configuration
   - Mounts `~/.ssh` for SSH keys (read-only)
   - Mounts `~/.config/github-copilot` for Copilot credentials
   - Creates a user with your exact UID and GID to maintain file permissions
   - Gives the user passwordless sudo access
   - Executes `copilot --yolo` in the workspace directory

## Troubleshooting

### Docker not found
Make sure Docker is installed and running:
```bash
docker --version
```

### Permission issues
The container runs with your user ID and group ID, so file permissions should be maintained. If you encounter issues, check your Docker installation allows non-root users.

### Authentication issues
Make sure you're logged in to GitHub Copilot:
```bash
# On your host machine, first time setup
gh auth login
# or use the copilot CLI directly to authenticate
```

### Rebuilding the image
If you want to get the latest copilot-cli version, rebuild the image:
```bash
copilot_yolo --rebuild
```

## License

MIT License - see [LICENSE](LICENSE) file for details.