#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
  local_version=""
  if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
    local_version="$(cat "${SCRIPT_DIR}/VERSION" | tr -d '\n' | tr -d ' ')"
  fi
  
  if command -v curl >/dev/null 2>&1; then
    remote_version="$(curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/VERSION" 2>/dev/null | tr -d '\n' | tr -d ' ' || true)"
    
    if [[ -n "${remote_version}" && "${remote_version}" != "${local_version}" ]]; then
      echo "copilot_yolo update available: ${local_version:-unknown} -> ${remote_version}"
      echo "Updating from ${REPO}/${BRANCH}..."
      
      temp_dir="$(mktemp -d)"
      trap 'rm -rf "${temp_dir}"' EXIT
      
      if curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/.copilot_yolo.sh" -o "${temp_dir}/.copilot_yolo.sh" && \
         curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/.copilot_yolo.Dockerfile" -o "${temp_dir}/.copilot_yolo.Dockerfile" && \
         curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/.copilot_yolo_entrypoint.sh" -o "${temp_dir}/.copilot_yolo_entrypoint.sh" && \
         curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/.dockerignore" -o "${temp_dir}/.dockerignore" 2>/dev/null && \
         curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/VERSION" -o "${temp_dir}/VERSION"; then
        
        chmod +x "${temp_dir}/.copilot_yolo.sh"
        cp "${temp_dir}/.copilot_yolo.sh" "${SCRIPT_DIR}/.copilot_yolo.sh"
        cp "${temp_dir}/.copilot_yolo.Dockerfile" "${SCRIPT_DIR}/.copilot_yolo.Dockerfile"
        cp "${temp_dir}/.copilot_yolo_entrypoint.sh" "${SCRIPT_DIR}/.copilot_yolo_entrypoint.sh"
        cp "${temp_dir}/.dockerignore" "${SCRIPT_DIR}/.dockerignore" 2>/dev/null || true
        cp "${temp_dir}/VERSION" "${SCRIPT_DIR}/VERSION"
        
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
for arg in "$@"; do
  if [[ "${arg}" == "--pull" ]]; then
    PULL_REQUESTED=1
    continue
  fi
  pass_args+=("${arg}")
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
if docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  image_exists=1
  image_version="$(docker run --rm "${IMAGE}" cat /opt/copilot-version 2>/dev/null || true)"
  image_version="$(printf '%s' "${image_version}" | tr -d '\n')"
  if [[ -n "${image_version}" ]]; then
    echo "Current Docker image has GitHub Copilot CLI version: ${image_version}"
  fi
fi

need_build=0
if [[ "${COPILOT_BUILD_NO_CACHE:-0}" == "1" || "${COPILOT_BUILD_PULL:-0}" == "1" || "${PULL_REQUESTED}" == "1" ]]; then
  need_build=1
  echo "Rebuild requested via flags."
elif [[ "${image_exists}" == "0" ]]; then
  need_build=1
  echo "Docker image not found. Building new image..."
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
  -v "${HOME}/.config/github-copilot:${CONTAINER_HOME}/.config/github-copilot"
  -w "${CONTAINER_WORKDIR}"
)

if [[ -t 1 ]]; then
  docker_args+=("-t")
fi

if [[ -f "${HOME}/.gitconfig" ]]; then
  docker_args+=("-v" "${HOME}/.gitconfig:${CONTAINER_HOME}/.gitconfig:ro")
fi

if [[ -d "${HOME}/.ssh" ]]; then
  docker_args+=("-v" "${HOME}/.ssh:${CONTAINER_HOME}/.ssh:ro")
fi

if [[ "${COPILOT_DRY_RUN:-0}" == "1" ]]; then
  if [[ "${need_build}" == "1" ]]; then
    echo "Dry run: would build image with:"
    printf 'DOCKER_BUILDKIT=1 docker build %q ' "${build_args[@]}"
    printf '%q ' "-t" "${IMAGE}" "-f" "${DOCKERFILE}" "${SCRIPT_DIR}"
    printf '\n'
  fi

  echo "Dry run: would run:"
  printf 'docker run %q ' "${docker_args[@]}"
  printf '%q ' "${IMAGE}"
  if [[ "${#pass_args[@]}" -gt 0 && "${pass_args[0]}" == "login" ]]; then
    printf 'copilot '
    printf '%q ' "${pass_args[@]}"
  else
    printf 'copilot yolo '
    printf '%q ' "${pass_args[@]}"
  fi
  printf '\n'
  exit 0
fi

# Ensure host config dir exists so Docker doesn't create it as root.
if ! mkdir -p "${HOME}/.config/github-copilot"; then
  echo "Error: unable to create ${HOME}/.config/github-copilot on the host."
  exit 1
fi

if [[ ! -w "${HOME}/.config/github-copilot" ]]; then
  echo "Error: ${HOME}/.config/github-copilot is not writable."
  echo "Check permissions or set HOME to a writable directory."
  exit 1
fi

if [[ -z "${latest_version}" && "${image_exists}" == "1" && "${COPILOT_SKIP_VERSION_CHECK:-0}" != "1" ]]; then
  echo "Warning: could not check latest @github/copilot version; using existing image."
fi

if [[ "${need_build}" == "1" ]]; then
  if [[ -n "${latest_version}" && -n "${image_version}" && "${latest_version}" != "${image_version}" ]]; then
    echo "Building Docker image with GitHub Copilot CLI ${latest_version}..."
  elif [[ -n "${latest_version}" ]]; then
    echo "Building Docker image with GitHub Copilot CLI ${latest_version}..."
  else
    echo "Building Docker image..."
  fi
  # Force BuildKit to avoid the legacy builder deprecation warning.
  DOCKER_BUILDKIT=1 docker build "${build_args[@]}" -t "${IMAGE}" -f "${DOCKERFILE}" "${SCRIPT_DIR}"
  echo "Docker image built successfully!"
fi

if [[ "${#pass_args[@]}" -gt 0 && "${pass_args[0]}" == "login" ]]; then
  docker run "${docker_args[@]}" "${IMAGE}" copilot "${pass_args[@]}"
else
  docker run "${docker_args[@]}" "${IMAGE}" copilot yolo "${pass_args[@]}"
fi
