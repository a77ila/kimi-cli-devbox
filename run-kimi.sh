#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE=".docker/compose.yaml"
SERVICE_NAME="kimi-cli"

# Match the in-container user to the host user so files created in /workspace
# are owned by the host user instead of root.
export USER_UID=${USER_UID:-$(id -u)}
export USER_GID=${USER_GID:-$(id -g)}
export KIMI_VERSION=${KIMI_VERSION:-latest}

show_help() {
  cat <<EOF
Usage:
  ./run-kimi.sh [command] [args...]

Runs commands inside the Kimi Docker container.

Commands:
  help, -h, --help
      Show this help message.

  build
      Build (or rebuild) the Docker image.

  shell
      Open an interactive shell in the container.

  <command> [args...]
      Run any other command from the container workspace root.
      Example:
        ./run-kimi.sh ls -la
        ./run-kimi.sh bash -lc 'cd src && <your-command>'

If no command is provided, an interactive container session is started.

Environment variables:
  USER_UID      Host user ID to use inside the container (default: current user).
  USER_GID      Host group ID to use inside the container (default: current group).
  KIMI_VERSION  Version of @moonshot-ai/kimi-code to install (default: latest).
EOF
}

run_container() {
  exec docker compose --file "$COMPOSE_FILE" run --rm "$SERVICE_NAME" "$@"
}

# Make sure the persistent home directory exists before compose tries to mount it.
mkdir -p ".docker_data/kimi-home"

if [ "$#" -gt 0 ]; then
  case "$1" in
    help|-h|--help)
      show_help
      exit 0
      ;;

    build)
      exec docker compose --file "$COMPOSE_FILE" build "$SERVICE_NAME"
      ;;

    shell)
      run_container bash
      ;;

    *)
      run_container "$@"
      ;;
  esac
fi

# Build only if the image does not already exist. Run `./run-kimi.sh build` to
# force a rebuild after changing the Dockerfile or context.
image_name=$(docker compose --file "$COMPOSE_FILE" config --images | awk -v svc="$SERVICE_NAME" '$1 == svc {print $2}')
if [ -z "$image_name" ] || ! docker image inspect "$image_name" >/dev/null 2>&1; then
  docker compose --file "$COMPOSE_FILE" build "$SERVICE_NAME"
fi

run_container
