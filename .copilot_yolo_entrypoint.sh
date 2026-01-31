#!/bin/sh
set -eu

TARGET_UID="${TARGET_UID:-1000}"
TARGET_GID="${TARGET_GID:-1000}"
TARGET_USER="${TARGET_USER:-copilot}"
TARGET_GROUP="${TARGET_GROUP:-copilot}"
TARGET_HOME="${TARGET_HOME:-/home/copilot}"
CLEANUP="${COPILOT_YOLO_CLEANUP:-1}"

# Performance: only run cleanup if changes were made
workspace_changed=0
check_workspace_ownership() {
  if [ -d /workspace ]; then
    # Check if any files are not owned by target user
    if [ -n "$(find /workspace ! -uid "${TARGET_UID}" -o ! -gid "${TARGET_GID}" 2>/dev/null | head -n 1)" ]; then
      workspace_changed=1
    fi
  fi
}

cleanup() {
  if [ "${CLEANUP}" = "1" ] || [ "${CLEANUP}" = "true" ]; then
    if [ "${workspace_changed}" = "1" ] && [ -d /workspace ]; then
      echo "Restoring workspace permissions..." >&2
      chown -R "${TARGET_UID}:${TARGET_GID}" /workspace 2>/dev/null || true
    fi
  fi
}

trap 'check_workspace_ownership; cleanup' EXIT

case "${TARGET_HOME}" in
  /*) ;;
  *) TARGET_HOME="/home/copilot" ;;
esac

if getent group "${TARGET_GID}" >/dev/null 2>&1; then
  TARGET_GROUP="$(getent group "${TARGET_GID}" | cut -d: -f1)"
else
  if getent group "${TARGET_GROUP}" >/dev/null 2>&1; then
    TARGET_GROUP="copilot-${TARGET_GID}"
  fi
  groupadd -g "${TARGET_GID}" "${TARGET_GROUP}"
fi

if getent passwd "${TARGET_UID}" >/dev/null 2>&1; then
  TARGET_USER="$(getent passwd "${TARGET_UID}" | cut -d: -f1)"
  if command -v usermod >/dev/null 2>&1; then
    usermod -d "${TARGET_HOME}" "${TARGET_USER}" >/dev/null 2>&1 || true
  fi
else
  if getent passwd "${TARGET_USER}" >/dev/null 2>&1; then
    TARGET_USER="copilot-${TARGET_UID}"
  fi
  useradd -M -u "${TARGET_UID}" -g "${TARGET_GID}" -s /bin/sh -d "${TARGET_HOME}" "${TARGET_USER}"
fi

mkdir -p "${TARGET_HOME}/.config/github-copilot" /etc/sudoers.d
chown -R "${TARGET_UID}:${TARGET_GID}" "${TARGET_HOME}" 2>/dev/null || true

printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${TARGET_USER}" > /etc/sudoers.d/90-copilot
chmod 0440 /etc/sudoers.d/90-copilot

if [ "$#" -eq 0 ]; then
  gosu "${TARGET_UID}:${TARGET_GID}" /bin/sh
  exit $?
fi

gosu "${TARGET_UID}:${TARGET_GID}" "$@"
status=$?
exit "${status}"
