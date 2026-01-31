#!/usr/bin/env bash
# Logging utilities for copilot_yolo

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Default log level
COPILOT_LOG_LEVEL="${COPILOT_LOG_LEVEL:-${LOG_LEVEL_INFO}}"

# Log directory
COPILOT_LOG_DIR="${COPILOT_LOG_DIR:-${HOME}/.copilot_yolo/logs}"

# Enable logging to file (disabled by default)
COPILOT_LOG_FILE="${COPILOT_LOG_FILE:-}"

log_message() {
  local level="$1"
  local level_num="$2"
  local message="$3"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  
  # Only log if level is high enough
  if [[ "${level_num}" -ge "${COPILOT_LOG_LEVEL}" ]]; then
    echo "[${timestamp}] [${level}] ${message}" >&2
  fi
  
  # Log to file if enabled
  if [[ -n "${COPILOT_LOG_FILE}" ]]; then
    mkdir -p "$(dirname "${COPILOT_LOG_FILE}")"
    echo "[${timestamp}] [${level}] ${message}" >> "${COPILOT_LOG_FILE}"
  fi
}

log_debug() {
  log_message "DEBUG" "${LOG_LEVEL_DEBUG}" "$1"
}

log_info() {
  log_message "INFO" "${LOG_LEVEL_INFO}" "$1"
}

log_warn() {
  log_message "WARN" "${LOG_LEVEL_WARN}" "$1"
}

log_error() {
  log_message "ERROR" "${LOG_LEVEL_ERROR}" "$1"
}

# Error handling with context
handle_error() {
  local exit_code="$1"
  local error_msg="$2"
  local suggestion="${3:-}"
  
  log_error "${error_msg}"
  
  if [[ -n "${suggestion}" ]]; then
    echo "Suggestion: ${suggestion}" >&2
  fi
  
  if [[ -n "${COPILOT_LOG_FILE}" ]]; then
    echo "Check logs at: ${COPILOT_LOG_FILE}" >&2
  fi
  
  exit "${exit_code}"
}
