#!/usr/bin/env bash
# Configuration file support for copilot_yolo

# Get the script directory (will be set by main script)
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Configuration file location - always in installation directory
COPILOT_CONFIG_FILE="${SCRIPT_DIR}/.copilot_yolo.conf"

load_config() {
  # Load configuration if it exists in installation directory
  if [[ -f "${COPILOT_CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${COPILOT_CONFIG_FILE}"
    return 0
  fi
  
  return 1
}

# Generate a sample configuration file
generate_sample_config() {
  local output_file="${1:-${COPILOT_CONFIG_FILE}}"
  
  cat > "${output_file}" <<'EOF'
# copilot_yolo configuration file
# 
# This file is sourced as a bash script, so you can use shell variables.
# Environment variables set here will be available to copilot_yolo.

# Docker image settings
# COPILOT_BASE_IMAGE="node:20-slim"
# COPILOT_YOLO_IMAGE="copilot-cli-yolo:local"

# Paths
# COPILOT_YOLO_HOME="/home/copilot"
# COPILOT_YOLO_WORKDIR="/workspace"

# Behavior
# COPILOT_YOLO_CLEANUP="1"
# COPILOT_SKIP_UPDATE_CHECK="0"
# COPILOT_SKIP_VERSION_CHECK="0"

# Build options
# COPILOT_BUILD_NO_CACHE="0"
# COPILOT_BUILD_PULL="0"

# Repository (for updates)
# COPILOT_YOLO_REPO="laurenceputra/copilot_yolo"
# COPILOT_YOLO_BRANCH="main"

# Logging (requires logging support)
# COPILOT_LOG_LEVEL="1"  # 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR
# COPILOT_LOG_FILE="${HOME}/.copilot_yolo/logs/copilot_yolo.log"

# Custom Docker arguments (advanced)
# Add any custom docker run arguments
# COPILOT_DOCKER_EXTRA_ARGS=("-e" "MY_VAR=value" "-v" "/host/path:/container/path")
EOF
  
  echo "Sample configuration generated at: ${output_file}"
  echo "Edit this file to customize copilot_yolo behavior."
}
