#!/usr/bin/env bash

# copilot_yolo - Run GitHub Copilot CLI in Docker with Yolo mode
# 
# This script runs the GitHub Copilot CLI in a Docker container with:
# - Your current workspace mounted
# - Git config and SSH keys mounted
# - GitHub Copilot credentials mounted
# - User matching your UID/GID with sudo access
# - Copilot running in Yolo (autonomous) mode

set -e

# Configuration
DOCKER_IMAGE="copilot_yolo:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print error messages
error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

# Function to print success messages
success() {
    echo -e "${GREEN}$1${NC}"
}

# Function to print info messages
info() {
    echo -e "${YELLOW}$1${NC}"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Run GitHub Copilot CLI in Docker with Yolo mode

OPTIONS:
    --workspace DIR    Workspace directory to mount (default: current directory)
    --rebuild          Force rebuild of the Docker image
    -h, --help         Show this help message

EXAMPLES:
    $(basename "$0")                           # Run in current directory
    $(basename "$0") --workspace /path/to/project
    $(basename "$0") --rebuild                 # Rebuild Docker image first

EOF
}

# Function to check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed."
        echo "Please install Docker from https://docker.com" >&2
        return 1
    fi
    
    if ! docker --version &> /dev/null; then
        error "Docker is not available or not running."
        echo "Please install Docker and ensure it's running." >&2
        echo "Common fixes:" >&2
        echo "  - Start Docker daemon: sudo systemctl start docker" >&2
        echo "  - Add user to docker group: sudo usermod -aG docker \$USER" >&2
        return 1
    fi
    
    return 0
}

# Function to check if Docker image exists
check_docker_image_exists() {
    docker image inspect "$DOCKER_IMAGE" &> /dev/null
}

# Function to build Docker image
build_docker_image() {
    local dockerfile_dir="$SCRIPT_DIR"
    
    # Check if Dockerfile exists in script directory
    if [[ ! -f "$dockerfile_dir/Dockerfile" ]]; then
        error "Dockerfile not found in $dockerfile_dir"
        return 1
    fi
    
    info "Building Docker image: $DOCKER_IMAGE"
    echo "This may take a few minutes on first run..."
    
    if docker build -t "$DOCKER_IMAGE" "$dockerfile_dir"; then
        success "Docker image built successfully!"
        return 0
    else
        error "Failed to build Docker image"
        return 1
    fi
}

# Function to get current user info
get_user_info() {
    USER_ID=$(id -u)
    GROUP_ID=$(id -g)
    USERNAME=$(whoami)
}

# Function to ensure required directories exist
ensure_directories() {
    # Ensure github-copilot config directory exists
    if [[ ! -d "$HOME/.config/github-copilot" ]]; then
        mkdir -p "$HOME/.config/github-copilot"
        info "Created GitHub Copilot config directory: $HOME/.config/github-copilot"
    fi
}

# Function to get the latest available copilot version from npm
get_latest_copilot_version() {
    local latest_version
    latest_version=$(npm view @github/copilot version 2>/dev/null || echo "")
    echo "$latest_version"
}

# Function to get the installed copilot version from Docker image
get_installed_copilot_version() {
    local installed_version
    if check_docker_image_exists; then
        installed_version=$(docker run --rm "$DOCKER_IMAGE" npm list -g @github/copilot --depth=0 2>/dev/null | grep @github/copilot | sed 's/.*@github\/copilot@//' | sed 's/ .*//' || echo "")
        echo "$installed_version"
    else
        echo ""
    fi
}

# Function to check if rebuild is needed due to new version
check_version_and_rebuild() {
    # Skip if npm is not available
    if ! command -v npm &> /dev/null; then
        return 0
    fi
    
    local latest_version
    local installed_version
    
    info "Checking for new copilot CLI version..."
    latest_version=$(get_latest_copilot_version)
    
    if [[ -z "$latest_version" ]]; then
        # Unable to check version, skip
        return 0
    fi
    
    installed_version=$(get_installed_copilot_version)
    
    if [[ -z "$installed_version" ]]; then
        # No installed version, need to build
        return 1
    fi
    
    if [[ "$latest_version" != "$installed_version" ]]; then
        info "New copilot CLI version available: $latest_version (current: $installed_version)"
        info "Rebuilding Docker image with latest version..."
        return 1
    fi
    
    return 0
}

# Function to run copilot in Docker
run_copilot() {
    local workspace_dir="$1"
    shift
    local additional_args=("$@")
    
    get_user_info
    ensure_directories
    
    # Build docker command
    local docker_cmd=(
        docker run
        --rm
        -it
        -e "LOCAL_UID=$USER_ID"
        -e "LOCAL_GID=$GROUP_ID"
        -e "LOCAL_USER=$USERNAME"
        -v "$workspace_dir:/workspace"
    )
    
    # Mount git config if it exists
    if [[ -f "$HOME/.gitconfig" ]]; then
        docker_cmd+=(-v "$HOME/.gitconfig:/home/$USERNAME/.gitconfig:ro")
    fi
    
    # Mount SSH directory if it exists
    if [[ -d "$HOME/.ssh" ]]; then
        docker_cmd+=(-v "$HOME/.ssh:/home/$USERNAME/.ssh:ro")
    fi
    
    # Mount GitHub Copilot config directory (now guaranteed to exist)
    if [[ -d "$HOME/.config/github-copilot" ]]; then
        docker_cmd+=(-v "$HOME/.config/github-copilot:/home/$USERNAME/.config/github-copilot")
    fi
    
    # Set working directory
    docker_cmd+=(-w /workspace)
    
    # Add image
    docker_cmd+=("$DOCKER_IMAGE")
    
    # Add copilot command with Yolo mode
    docker_cmd+=(copilot yolo)
    
    # Add any additional arguments
    if [[ ${#additional_args[@]} -gt 0 ]]; then
        docker_cmd+=("${additional_args[@]}")
    fi
    
    # Print info
    echo "Running copilot in Yolo mode on: $workspace_dir"
    echo "User: $USERNAME (UID: $USER_ID, GID: $GROUP_ID)"
    echo "Container will have sudo access for installing packages"
    echo ""
    
    # Execute docker command with exec for better signal handling
    exec "${docker_cmd[@]}"
}

# Main function
main() {
    local workspace_dir="$PWD"
    local rebuild=false
    local additional_args=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --workspace)
                if [[ -z "${2:-}" ]]; then
                    error "--workspace requires a directory argument"
                    exit 1
                fi
                workspace_dir="$2"
                shift 2
                ;;
            --rebuild)
                rebuild=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                additional_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Check if Docker is available
    if ! check_docker; then
        exit 1
    fi
    
    # Resolve workspace directory to absolute path
    if [[ ! -d "$workspace_dir" ]]; then
        error "Workspace directory does not exist: $workspace_dir"
        exit 1
    fi
    workspace_dir="$(cd "$workspace_dir" && pwd)"
    
    # Check if we need to rebuild due to version update or if rebuild flag is set
    local need_rebuild=false
    
    if [[ "$rebuild" == true ]]; then
        need_rebuild=true
    elif ! check_docker_image_exists; then
        need_rebuild=true
    elif ! check_version_and_rebuild; then
        # New version available
        need_rebuild=true
    fi
    
    # Build or rebuild the Docker image if needed
    if [[ "$need_rebuild" == true ]]; then
        if ! build_docker_image; then
            exit 1
        fi
    fi
    
    # Run copilot
    run_copilot "$workspace_dir" "${additional_args[@]}"
}

# Run main function
main "$@"
