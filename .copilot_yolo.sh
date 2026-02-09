#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration if available
if [[ -f "${SCRIPT_DIR}/.copilot_yolo_config.sh" ]]; then
  # shellcheck source=.copilot_yolo_config.sh
  source "${SCRIPT_DIR}/.copilot_yolo_config.sh"
  load_config || true
fi

IMAGE="${COPILOT_YOLO_IMAGE:-copilot-cli-yolo:local}"
DOCKERFILE="${SCRIPT_DIR}/.copilot_yolo.Dockerfile"
WORKSPACE="$(pwd)"
USER_ID="$(id -u)"
GROUP_ID="$(id -g)"
USER_NAME="$(id -un)"
GROUP_NAME="$(id -gn)"
CONTAINER_HOME="${COPILOT_YOLO_HOME:-/home/copilot}"
CONTAINER_WORKDIR="${COPILOT_YOLO_WORKDIR:-/workspace}"
BASE_IMAGE="${COPILOT_BASE_IMAGE:-node:20-slim}"
PULL_REQUESTED=0
REPO="${COPILOT_YOLO_REPO:-laurenceputra/copilot_yolo}"
BRANCH="${COPILOT_YOLO_BRANCH:-main}"
local_version=""
if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
  local_version="$(tr -d '\n ' < "${SCRIPT_DIR}/VERSION")"
fi

install_hint=""
case "$(uname -s)" in
  Darwin)
    install_hint="Install Docker Desktop: https://docs.docker.com/desktop/install/mac-install/"
    ;;
  Linux)
    install_hint="Install Docker Engine: https://docs.docker.com/engine/install/"
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    install_hint="Install Docker Desktop: https://docs.docker.com/desktop/install/windows-install/"
    ;;
  *)
    install_hint="Install Docker: https://docs.docker.com/get-docker/"
    ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not on PATH."
  echo "${install_hint}"
  exit 127
fi

if ! docker info >/dev/null 2>&1; then
  echo "Error: Docker is installed but the daemon is not running."
  echo "Start Docker Desktop or the Docker Engine service, then try again."
  echo "${install_hint}"
  exit 1
fi

# Check for updates unless explicitly disabled
if [[ "${COPILOT_SKIP_UPDATE_CHECK:-0}" != "1" ]]; then
  if command -v curl >/dev/null 2>&1; then
    remote_version="$(curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/VERSION" 2>/dev/null | tr -d '\n' | tr -d ' ' || true)"
    
    if [[ -n "${remote_version}" && "${remote_version}" != "${local_version}" ]]; then
      echo "copilot_yolo update available: ${local_version:-unknown} -> ${remote_version}"
      echo "Updating from ${REPO}/${BRANCH}..."
      
      temp_dir="$(mktemp -d)"
      trap 'rm -rf "${temp_dir}"' EXIT
      
      # Download files with a simple helper
      download_file() {
        local file="$1"
        local required="${2:-false}"
        if curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/${file}" -o "${temp_dir}/${file}" 2>/dev/null; then
          return 0
        elif [[ "${required}" == "true" ]]; then
          return 1
        fi
        return 0
      }
      
      # Download required files
      if download_file ".copilot_yolo.sh" true && \
         download_file ".copilot_yolo.Dockerfile" true && \
         download_file ".copilot_yolo_entrypoint.sh" true && \
         download_file "VERSION" true; then
        
        # Download optional files (non-fatal)
        download_file ".dockerignore"
        download_file ".copilot_yolo_config.sh"
        download_file ".copilot_yolo_completion.bash"
        download_file ".copilot_yolo_completion.zsh"
        
        # Copy all downloaded files
        chmod +x "${temp_dir}/.copilot_yolo.sh"
        # Required files
        for file in .copilot_yolo.sh .copilot_yolo.Dockerfile .copilot_yolo_entrypoint.sh VERSION; do
          [[ -f "${temp_dir}/${file}" ]] && cp "${temp_dir}/${file}" "${SCRIPT_DIR}/${file}"
        done
        # Optional files
        for file in .dockerignore .copilot_yolo_config.sh .copilot_yolo_completion.bash .copilot_yolo_completion.zsh; do
          [[ -f "${temp_dir}/${file}" ]] && cp "${temp_dir}/${file}" "${SCRIPT_DIR}/${file}"
        done
        
        echo "Updated to version ${remote_version}"
        echo "Re-executing with new version..."
        exec "${SCRIPT_DIR}/.copilot_yolo.sh" "$@"
      else
        echo "Warning: failed to download updates; continuing with local version."
      fi
    fi
  fi
fi

if [[ "${COPILOT_SKIP_VERSION_CHECK:-0}" != "1" ]] && ! docker buildx version >/dev/null 2>&1; then
  echo "Warning: docker buildx is not available; builds may be slower or fail on some systems."
  echo "Install Docker Buildx to improve build reliability: https://docs.docker.com/build/buildx/"
fi

pass_args=()
run_health_check=0
generate_config=0
mount_ssh=0

# Parse arguments
for arg in "$@"; do
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
    --mount-ssh)
      mount_ssh=1
      ;;
    *)
      pass_args+=("${arg}")
      ;;
  esac
done

if [[ "${CONTAINER_HOME}" != /* ]]; then
  echo "Error: COPILOT_YOLO_HOME must be an absolute path inside the container."
  exit 1
fi

if [[ "${CONTAINER_WORKDIR}" != /* ]]; then
  echo "Error: COPILOT_YOLO_WORKDIR must be an absolute path inside the container."
  exit 1
fi

if [[ "${IMAGE}" != "copilot-cli-yolo:local" ]]; then
  echo "Warning: COPILOT_YOLO_IMAGE is set to a non-default image; use only images you trust."
fi

# Build the image locally (no community image pull).
build_args=(--build-arg "BASE_IMAGE=${BASE_IMAGE}")
if [[ -n "${local_version}" ]]; then
  build_args+=(--build-arg "COPILOT_YOLO_VERSION=${local_version}")
fi
if [[ "${COPILOT_BUILD_NO_CACHE:-0}" == "1" ]]; then
  build_args+=(--no-cache)
fi
if [[ "${COPILOT_BUILD_PULL:-0}" == "1" || "${PULL_REQUESTED}" == "1" ]]; then
  build_args+=(--pull)
fi

latest_version=""
if [[ "${COPILOT_SKIP_VERSION_CHECK:-0}" != "1" ]]; then
  echo "Checking for latest GitHub Copilot CLI version..."
  if command -v npm >/dev/null 2>&1; then
    latest_version="$(npm view @github/copilot version 2>/dev/null || true)"
  else
    echo "npm not found locally, using Docker to check version..."
    latest_version="$(docker run --rm node:20-slim npm view @github/copilot version 2>/dev/null || true)"
  fi
  latest_version="$(printf '%s' "${latest_version}" | tr -d '\n')"
  
  if [[ -n "${latest_version}" ]]; then
    echo "Latest GitHub Copilot CLI version: ${latest_version}"
  else
    echo "Warning: Unable to fetch latest version from npm registry."
  fi
fi

if [[ -n "${latest_version}" ]]; then
  build_args+=(--build-arg "COPILOT_VERSION=${latest_version}")
fi

image_exists=0
image_version=""
image_yolo_version=""
if docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  image_exists=1
  image_version="$(docker run --rm "${IMAGE}" cat /opt/copilot-version 2>/dev/null || true)"
  image_version="$(printf '%s' "${image_version}" | tr -d '\n')"
  if [[ -n "${image_version}" ]]; then
    echo "Current Docker image has GitHub Copilot CLI version: ${image_version}"
  fi
  image_yolo_version="$(docker run --rm "${IMAGE}" cat /opt/copilot-yolo-version 2>/dev/null || true)"
  image_yolo_version="$(printf '%s' "${image_yolo_version}" | tr -d '\n')"
  if [[ -n "${image_yolo_version}" ]]; then
    echo "Current Docker image has copilot_yolo version: ${image_yolo_version}"
  fi
fi

need_build=0
if [[ "${COPILOT_BUILD_NO_CACHE:-0}" == "1" || "${COPILOT_BUILD_PULL:-0}" == "1" || "${PULL_REQUESTED}" == "1" ]]; then
  need_build=1
  echo "Rebuild requested via flags."
elif [[ "${image_exists}" == "0" ]]; then
  need_build=1
  echo "Docker image not found. Building new image..."
elif [[ -n "${local_version}" ]]; then
  if [[ -z "${image_yolo_version}" || "${local_version}" != "${image_yolo_version}" ]]; then
    need_build=1
    if [[ -z "${image_yolo_version}" ]]; then
      echo "Cannot determine current copilot_yolo image version. Rebuilding to ensure latest version..."
    else
      echo "copilot_yolo version changed: ${image_yolo_version} -> ${local_version}"
      echo "Rebuilding Docker image to match copilot_yolo version..."
    fi
  fi
elif [[ -n "${latest_version}" ]]; then
  if [[ -z "${image_version}" || "${latest_version}" != "${image_version}" ]]; then
    need_build=1
    if [[ -z "${image_version}" ]]; then
      echo "Cannot determine current image version. Rebuilding to ensure latest version..."
    else
      echo "New version available: ${image_version} -> ${latest_version}"
      echo "Rebuilding Docker image with latest GitHub Copilot CLI..."
    fi
  else
    echo "Docker image is up to date with version ${image_version}"
  fi
fi

docker_args=(
  --rm -i
  -e HOME="${CONTAINER_HOME}"
  -e TARGET_UID="${USER_ID}"
  -e TARGET_GID="${GROUP_ID}"
  -e TARGET_USER="${USER_NAME}"
  -e TARGET_GROUP="${GROUP_NAME}"
  -e TARGET_HOME="${CONTAINER_HOME}"
  -e COPILOT_YOLO_CLEANUP="${COPILOT_YOLO_CLEANUP:-1}"
  -v "${WORKSPACE}:${CONTAINER_WORKDIR}"
  -w "${CONTAINER_WORKDIR}"
)

if [[ -n "${GH_TOKEN:-}" ]]; then
  docker_args+=("-e" "GH_TOKEN=${GH_TOKEN}")
fi

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  docker_args+=("-e" "GITHUB_TOKEN=${GITHUB_TOKEN}")
fi

# Mount ~/.copilot if it exists to use host login details
if [[ -d "${HOME}/.copilot" ]]; then
  docker_args+=("-v" "${HOME}/.copilot:${CONTAINER_HOME}/.copilot")
fi

# Mount gh config if it exists to use host authentication
host_gh_config="${XDG_CONFIG_HOME:-$HOME/.config}/gh"
if [[ -d "${host_gh_config}" ]]; then
  docker_args+=("-v" "${host_gh_config}:${CONTAINER_HOME}/.config/gh")
fi

if [[ -t 1 ]]; then
  docker_args+=("-t")
fi

if [[ -f "${HOME}/.gitconfig" ]]; then
  docker_args+=("-v" "${HOME}/.gitconfig:${CONTAINER_HOME}/.gitconfig:ro")
fi

# Generate config command
if [[ "${generate_config}" == "1" ]]; then
  if [[ -f "${SCRIPT_DIR}/.copilot_yolo_config.sh" ]]; then
    # shellcheck source=.copilot_yolo_config.sh
    source "${SCRIPT_DIR}/.copilot_yolo_config.sh"
    generate_sample_config
  else
    echo "Error: Configuration support not available in this installation."
    exit 1
  fi
  exit 0
fi

# Health check command
if [[ "${run_health_check}" == "1" ]]; then
  echo "=== copilot_yolo Health Check ==="
  echo ""
  
  # Check Docker
  if command -v docker >/dev/null 2>&1; then
    echo "✓ Docker: $(docker --version)"
    if docker info >/dev/null 2>&1; then
      echo "✓ Docker daemon: running"
    else
      echo "✗ Docker daemon: not running"
      echo "  Start Docker Desktop or the Docker Engine service"
    fi
  else
    echo "✗ Docker: not installed"
    echo "  ${install_hint}"
  fi
  
  # Check Docker Buildx
  if docker buildx version >/dev/null 2>&1; then
    echo "✓ Docker Buildx: $(docker buildx version | head -n1)"
  else
    echo "⚠ Docker Buildx: not available (builds may be slower)"
    echo "  https://docs.docker.com/build/buildx/"
  fi
  
  # Check copilot_yolo version
  echo "✓ copilot_yolo version: ${local_version:-unknown}"
  
  # Check image status
  if docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    image_version="$(docker run --rm "${IMAGE}" cat /opt/copilot-version 2>/dev/null || true)"
    echo "✓ Docker image: exists (Copilot CLI ${image_version:-unknown})"
  else
    echo "⚠ Docker image: not built yet (will build on first run)"
  fi
  
  # Check latest CLI version
  if [[ -n "${latest_version}" ]]; then
    echo "✓ Latest Copilot CLI: ${latest_version}"
  fi
  
  # Check mounts
  echo ""
  echo "=== Mounted Paths ==="
  [[ -d "${HOME}/.copilot" ]] && echo "✓ ~/.copilot (credentials)" || echo "⚠ ~/.copilot not found (will need to login)"
  [[ -d "${host_gh_config}" ]] && echo "✓ ${host_gh_config} (gh CLI auth)" || echo "⚠ gh config not found"
  [[ -f "${HOME}/.gitconfig" ]] && echo "✓ ~/.gitconfig (git config)" || echo "⚠ ~/.gitconfig not found"
  if [[ -d "${HOME}/.ssh" ]]; then
    echo "✓ ~/.ssh available (use --mount-ssh to enable, with caution)"
  else
    echo "⚠ ~/.ssh not found"
  fi
  
  echo ""
  echo "=== Status ==="
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "✓ Ready to use! Run: copilot_yolo"
  else
    echo "✗ Not ready. Fix the issues above."
  fi
  
  exit 0
fi

# Mount SSH directory if requested (with security warning)
if [[ "${mount_ssh}" == "1" ]]; then
  if [[ -d "${HOME}/.ssh" ]]; then
    echo "⚠ WARNING: Mounting SSH keys into the container!"
    echo "⚠ Please ensure you have proper branch protection rules in place."
    echo "⚠ Protect critical branches (main, master, production) to prevent accidental pushes."
    echo ""
    docker_args+=("-v" "${HOME}/.ssh:${CONTAINER_HOME}/.ssh:ro")
  else
    echo "Warning: --mount-ssh specified but ~/.ssh directory not found"
  fi
fi

# Build copilot command based on arguments
copilot_cmd=(copilot)
if [[ "${#pass_args[@]}" -eq 0 || "${pass_args[0]}" != "login" ]]; then
  copilot_cmd+=(--yolo)
fi
copilot_cmd+=("${pass_args[@]}")

if [[ "${COPILOT_DRY_RUN:-0}" == "1" ]]; then
  if [[ "${need_build}" == "1" ]]; then
    echo "Dry run: would build image with:"
    printf 'DOCKER_BUILDKIT=1 docker build'
    printf ' %q' "${build_args[@]}"
    printf ' -t %q -f %q %q\n' "${IMAGE}" "${DOCKERFILE}" "${SCRIPT_DIR}"
  fi

  echo "Dry run: would run:"
  printf 'docker run'
  printf ' %q' "${docker_args[@]}"
  printf ' %q' "${IMAGE}"
  printf ' %q' "${copilot_cmd[@]}"
  printf '\n'
  exit 0
fi

if [[ -z "${latest_version}" && "${image_exists}" == "1" && "${COPILOT_SKIP_VERSION_CHECK:-0}" != "1" ]]; then
  echo "Warning: could not check latest @github/copilot version; using existing image."
fi

if [[ "${need_build}" == "1" ]]; then
  # Only show build message if we haven't already shown a more specific one
  if [[ "${COPILOT_BUILD_NO_CACHE:-0}" == "1" || "${COPILOT_BUILD_PULL:-0}" == "1" || "${PULL_REQUESTED}" == "1" ]]; then
    if [[ -n "${latest_version}" ]]; then
      echo "Building Docker image with GitHub Copilot CLI ${latest_version}..."
    else
      echo "Building Docker image..."
    fi
  elif [[ "${image_exists}" == "0" ]]; then
    # Message already shown earlier: "Docker image not found. Building new image..."
    :
  elif [[ -n "${latest_version}" && -n "${image_version}" && "${latest_version}" != "${image_version}" ]]; then
    # Message already shown earlier: "Rebuilding Docker image with latest GitHub Copilot CLI..."
    :
  fi
  # Force BuildKit to avoid the legacy builder deprecation warning.
  DOCKER_BUILDKIT=1 docker build "${build_args[@]}" -t "${IMAGE}" -f "${DOCKERFILE}" "${SCRIPT_DIR}"
  echo "Docker image built successfully!"
fi

docker run "${docker_args[@]}" "${IMAGE}" "${copilot_cmd[@]}"
