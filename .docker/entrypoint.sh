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

# Keep Kimi runtime data inside the mounted per-project home directory.
KIMI_CODE_HOME="${KIMI_CODE_HOME:-/home/kimi/.kimi-code}"
mkdir -p "$KIMI_CODE_HOME"
export KIMI_CODE_HOME

# Ensure the mounted home directory is writable by the user.  /workspace is
# deliberately NOT chowned: it is the user's real project and its ownership
# must be left alone.
chown -R "$USER_UID:$USER_GID" /home/"$USERNAME" 2>/dev/null || true

exec su-exec "$USERNAME" "$@"
