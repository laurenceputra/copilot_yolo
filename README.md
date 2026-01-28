# copilot_yolo

A command-line tool that runs the latest GitHub Copilot CLI in Docker with Yolo mode, automatically mounting necessary directories and maintaining user permissions with sudo access.

**No installation required!** Just Docker and Bash (which comes with most Unix systems).

## Features

- 🐳 Runs the latest `copilot` CLI in Docker (no local installation needed)
- 🔐 Mounts Git config and SSH keys for authentication
- 💾 Mounts GitHub Copilot credentials directory
- 📁 Mounts your current working directory as the workspace
- 👤 Maintains your user ID and group ID in the container
- 🔑 Provides sudo access within the container for installing packages
- 🚀 Runs copilot in Yolo mode automatically
- ⚡ Pure Bash - no Python or other dependencies needed

## What is Yolo Mode?

Yolo mode is GitHub Copilot's autonomous mode where the AI agent can:
- Analyze your codebase
- Make changes directly to your files
- Execute commands
- Work on complex tasks with minimal human intervention

## Prerequisites

- Docker installed and running
- Bash (comes pre-installed on Linux and macOS)

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/laurenceputra/copilot_yolo.git
cd copilot_yolo

# Make the script executable (if not already)
chmod +x copilot_yolo.sh

# Optionally, install to your PATH
sudo cp copilot_yolo.sh /usr/local/bin/copilot_yolo
```

### Manual Installation

Just download the `copilot_yolo.sh` script and make it executable:

```bash
curl -o copilot_yolo https://raw.githubusercontent.com/laurenceputra/copilot_yolo/main/copilot_yolo.sh
chmod +x copilot_yolo
# Move to a directory in your PATH
sudo mv copilot_yolo /usr/local/bin/
```

## Usage

### Basic Usage

Simply run `copilot_yolo.sh` (or `copilot_yolo` if installed to PATH) in any directory where you want to use GitHub Copilot:

```bash
cd /path/to/your/project
./copilot_yolo.sh
```

Or if installed to PATH:

```bash
cd /path/to/your/project
copilot_yolo
```

This will:
1. Build a custom Docker image (first run only - takes a few minutes)
2. Mount your current directory to `/workspace` in the container
3. Mount your Git config, SSH keys, and Copilot credentials
4. Create a user in the container with your UID/GID
5. Give the user sudo access (no password required)
6. Run `copilot yolo` on your workspace

### Options

```bash
# Show help
./copilot_yolo.sh --help

# Specify a different workspace directory
./copilot_yolo.sh --workspace /path/to/project

# Force rebuild of the Docker image (to get latest copilot CLI)
./copilot_yolo.sh --rebuild
```

### Using Sudo in the Container

The container is set up with a user matching your UID/GID that has passwordless sudo access. This allows Copilot to install packages or perform other administrative tasks when needed.

## How It Works

The tool:
1. Builds a custom Docker image based on `node:18-slim`
2. Installs `@github/copilot` from npm
3. Adds sudo support and a custom entrypoint script
4. Creates a Docker container that:
   - Uses your current working directory as `/workspace`
   - Mounts `~/.gitconfig` for Git configuration (read-only)
   - Mounts `~/.ssh` for SSH keys (read-only)
   - Mounts `~/.config/github-copilot` for Copilot credentials
   - Creates a user with your exact UID and GID to maintain file permissions
   - Gives the user passwordless sudo access
   - Executes `copilot yolo` in the workspace directory

## Project Structure

```
copilot_yolo/
├── copilot_yolo.sh    # Main bash script
├── Dockerfile         # Docker image definition
├── entrypoint.sh      # Container entrypoint for user setup
└── README.md          # This file
```

The bash script handles everything - checking Docker, building the image, and running the container with the right configuration.

## Directory Mounts

The following directories are automatically mounted from your host:

| Host Path | Container Path | Mode | Purpose |
|-----------|---------------|------|---------|
| Current working directory | `/workspace` | Read-write | Your project files |
| `~/.gitconfig` | `/home/<user>/.gitconfig` | Read-only | Git configuration |
| `~/.ssh` | `/home/<user>/.ssh` | Read-only | SSH keys for Git auth |
| `~/.config/github-copilot` | `/home/<user>/.config/github-copilot` | Read-write | Copilot credentials |

## Troubleshooting

### Docker not found
Make sure Docker is installed and running:
```bash
docker --version
```

### Permission issues
The container runs with your user ID and group ID, so file permissions should be maintained. If you encounter issues, check that your Docker installation allows non-root users to access Docker.

```bash
# Add your user to the docker group
sudo usermod -aG docker $USER
# Log out and back in for changes to take effect
```

### Authentication issues
Make sure you're logged in to GitHub Copilot. On first run, the Copilot CLI will prompt you to authenticate:

```bash
# The CLI will guide you through authentication
./copilot_yolo.sh
# or if installed to PATH
copilot_yolo
```

### Rebuilding the image
If you want to get the latest copilot CLI version, rebuild the image:
```bash
./copilot_yolo.sh --rebuild
# or if installed to PATH
copilot_yolo --rebuild
```

### SSL Certificate Issues
If you're behind a corporate proxy with SSL inspection, you may need to configure Docker to trust your corporate certificates. The Dockerfile includes a workaround for npm SSL issues during the build.

## Example Workflow

```bash
# Navigate to your project
cd ~/my-project

# Run copilot in Yolo mode (if installed to PATH)
copilot_yolo

# Or run the script directly
./copilot_yolo.sh

# Copilot will analyze your project and wait for instructions
# You can ask it to:
# - "Add unit tests for the auth module"
# - "Refactor the database layer to use TypeScript"
# - "Fix all linting errors"
# - "Update dependencies to latest versions"
```

## Limitations

- Requires Docker to be installed and running
- First run takes a few minutes to build the Docker image
- Internet connection required to pull base image and install copilot
- Requires Bash (available by default on Linux and macOS)

## Security Considerations

This tool is designed for development environments. Be aware of the following:

1. **Yolo Mode**: Runs Copilot in autonomous mode, which can make changes to your files without explicit confirmation
2. **Workspace Access**: The container has read-write access to your workspace directory
3. **Sudo Access**: The container user has passwordless sudo to install packages as needed
4. **Credentials**: GitHub Copilot credentials are mounted to enable authentication
5. **SSL in Corporate Environments**: The Dockerfile disables SSL verification during npm install to support corporate proxies with SSL inspection

**Recommendation**: Only use this tool in trusted development environments and on code you're comfortable having an AI agent modify.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) file for details.