#!/usr/bin/env python3
"""CLI tool to run GitHub Copilot CLI in Docker with Yolo mode."""

import os
import sys
import subprocess
import argparse
import pwd
from pathlib import Path


def get_docker_image():
    """Get the Docker image to use for copilot-cli."""
    return "copilot_yolo:latest"


def get_dockerfile_dir():
    """Get the directory containing the Dockerfile."""
    # Get the directory of this script
    return Path(__file__).parent


def get_uid_gid():
    """Get current user's UID and GID."""
    uid = os.getuid()
    gid = os.getgid()
    return uid, gid


def get_username():
    """Get current username."""
    return pwd.getpwuid(os.getuid()).pw_name


def build_docker_image():
    """Build the custom Docker image with sudo support."""
    dockerfile_dir = get_dockerfile_dir()
    image = get_docker_image()
    
    print(f"Building Docker image: {image}")
    print("This may take a few minutes on first run...")
    
    try:
        subprocess.run(
            ["docker", "build", "-t", image, str(dockerfile_dir)],
            check=True
        )
        print("Docker image built successfully!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error: Failed to build Docker image: {e}", file=sys.stderr)
        return False


def check_docker_image_exists():
    """Check if the custom Docker image exists."""
    image = get_docker_image()
    try:
        result = subprocess.run(
            ["docker", "image", "inspect", image],
            capture_output=True,
            check=False
        )
        return result.returncode == 0
    except Exception:
        return False


def build_docker_command(workspace_dir, additional_args=None):
    """
    Build the docker run command with all necessary mounts and settings.
    
    Args:
        workspace_dir: The directory to mount as workspace
        additional_args: Additional arguments to pass to copilot
    
    Returns:
        List of command arguments
    """
    uid, gid = get_uid_gid()
    username = get_username()
    home_dir = str(Path.home())
    
    # Base docker command
    cmd = [
        "docker", "run",
        "--rm",  # Remove container after exit
        "-it",   # Interactive with TTY
        # Pass user information to entrypoint
        "-e", f"LOCAL_UID={uid}",
        "-e", f"LOCAL_GID={gid}",
        "-e", f"LOCAL_USER={username}",
        # Mount current working directory to /workspace
        "-v", f"{workspace_dir}:/workspace",
        # Mount git config
        "-v", f"{home_dir}/.gitconfig:/home/{username}/.gitconfig:ro",
    ]
    
    # Mount SSH directory if it exists
    ssh_dir = Path(home_dir) / ".ssh"
    if ssh_dir.exists():
        cmd.extend(["-v", f"{ssh_dir}:/home/{username}/.ssh:ro"])
    
    # Mount GitHub Copilot config directory if it exists
    copilot_config_dir = Path(home_dir) / ".config" / "github-copilot"
    if copilot_config_dir.exists():
        cmd.extend(["-v", f"{copilot_config_dir}:/home/{username}/.config/github-copilot"])
    
    # Set working directory
    cmd.extend(["-w", "/workspace"])
    
    # Add the image
    cmd.append(get_docker_image())
    
    # Add copilot command with Yolo mode
    cmd.extend(["copilot", "yolo"])
    
    # Add any additional arguments
    if additional_args:
        cmd.extend(additional_args)
    
    return cmd


def check_docker():
    """Check if Docker is available."""
    try:
        result = subprocess.run(
            ["docker", "--version"],
            capture_output=True,
            text=True,
            check=False
        )
        if result.returncode != 0:
            print("Error: Docker is not available or not running.", file=sys.stderr)
            print("Please install Docker and ensure it's running.", file=sys.stderr)
            print("Common fixes:", file=sys.stderr)
            print("  - Start Docker daemon: sudo systemctl start docker", file=sys.stderr)
            print("  - Add user to docker group: sudo usermod -aG docker $USER", file=sys.stderr)
            return False
        return True
    except FileNotFoundError:
        print("Error: Docker is not installed.", file=sys.stderr)
        print("Please install Docker from https://docker.com", file=sys.stderr)
        return False
    except subprocess.SubprocessError as e:
        print(f"Error checking Docker: {e}", file=sys.stderr)
        return False


def main():
    """Main entry point for the CLI."""
    parser = argparse.ArgumentParser(
        description="Run GitHub Copilot CLI in Docker with Yolo mode",
        epilog="Any additional arguments will be passed to the copilot command."
    )
    parser.add_argument(
        "--workspace",
        default=os.getcwd(),
        help="Workspace directory to mount (default: current directory)"
    )
    parser.add_argument(
        "--rebuild",
        action="store_true",
        help="Force rebuild of the Docker image"
    )
    
    # Parse known args to allow passing through additional args to copilot
    args, additional_args = parser.parse_known_args()
    
    # Check if Docker is available
    if not check_docker():
        sys.exit(1)
    
    # Build or rebuild the Docker image if needed
    if args.rebuild or not check_docker_image_exists():
        if not build_docker_image():
            sys.exit(1)
    
    # Resolve workspace directory to absolute path
    workspace_dir = os.path.abspath(args.workspace)
    if not os.path.isdir(workspace_dir):
        print(f"Error: Workspace directory does not exist: {workspace_dir}", file=sys.stderr)
        sys.exit(1)
    
    # Build and execute docker command
    docker_cmd = build_docker_command(workspace_dir, additional_args)
    
    print(f"Running copilot in Yolo mode on: {workspace_dir}")
    print(f"User: {get_username()} (UID: {get_uid_gid()[0]}, GID: {get_uid_gid()[1]})")
    print(f"Container will have sudo access for installing packages")
    print()
    
    try:
        # Execute docker command, passing through stdin/stdout/stderr
        result = subprocess.run(docker_cmd)
        sys.exit(result.returncode)
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"Error running copilot: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
