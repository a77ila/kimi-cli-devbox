#!/usr/bin/env bash
# Adjust the in-container kimi user to match the host user's UID/GID so files
# created in /workspace are owned by the host user, not root.
set -euo pipefail

USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}

# Treat empty values as unset so a missing compose default does not break usermod.
[ -z "$USER_UID" ] && USER_UID=1000
[ -z "$USER_GID" ] && USER_GID=1000
USERNAME=kimi

if [ "$(id -u "$USERNAME")" != "$USER_UID" ]; then
  usermod -u "$USER_UID" "$USERNAME"
fi

if [ "$(id -g "$USERNAME")" != "$USER_GID" ]; then
  groupmod -g "$USER_GID" "$USERNAME"
fi

# Ensure the workspace and home directory are writable by the user.
chown -R "$USER_UID:$USER_GID" /workspace /home/"$USERNAME" 2>/dev/null || true

exec su-exec "$USERNAME" "$@"
