#!/bin/bash
set -e

# Get user information from environment variables
USER_ID=${LOCAL_UID:-9001}
GROUP_ID=${LOCAL_GID:-9001}
USERNAME=${LOCAL_USER:-developer}

# Create group if it doesn't exist with this GID
if ! getent group $GROUP_ID > /dev/null; then
    groupadd -g $GROUP_ID $USERNAME
fi

# Create user if it doesn't exist with this UID
if ! id -u $USER_ID > /dev/null 2>&1; then
    useradd -u $USER_ID -g $GROUP_ID -m -s /bin/bash $USERNAME
    
    # Add user to sudoers using sudoers.d (safer than editing /etc/sudoers directly)
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
    chmod 0440 /etc/sudoers.d/$USERNAME
fi

# Ensure home directory exists and has correct permissions
if [ ! -d "/home/$USERNAME" ]; then
    mkdir -p /home/$USERNAME
fi

# Try to change ownership, but don't fail if it's read-only
chown -R $USER_ID:$GROUP_ID /home/$USERNAME 2>/dev/null || true

# Switch to the user and execute the command
exec gosu $USER_ID:$GROUP_ID "$@"
