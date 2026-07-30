#!/usr/bin/env bash
set -euo pipefail

# Launcher for the Dockerised Kimi Code CLI.
#
# This script reads projects.yaml (gitignored) and mounts an external project
# into the container so the target project never needs its own copy of the
# devbox boilerplate.

DEVBOX_ROOT="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DEVBOX_ROOT/.docker/compose.yaml"
SERVICE_NAME="isolated-kimi-cli"
SELECT_PROJECT_SCRIPT="$DEVBOX_ROOT/scripts/select-project.sh"

# Match the in-container user to the host user so files created in /workspace
# are owned by the host user instead of root.
export USER_UID=${USER_UID:-$(id -u)}
export USER_GID=${USER_GID:-$(id -g)}
export KIMI_VERSION=${KIMI_VERSION:-latest}

show_help() {
  cat <<EOF
Usage:
  ./run-kimi.sh [command] [args...]

Runs commands inside the Kimi Docker container for a project configured in
projects.yaml.

Commands:
  help, -h, --help
      Show this help message.

  build
      Build (or rebuild) the Docker image.

  shell
      Open an interactive shell in the container for the selected project.

  <command> [args...]
      Run any other command from the selected project's container workspace.
      Example:
        ./run-kimi.sh ls -la
        ./run-kimi.sh bash -lc 'cd src && <your-command>'

If no command is provided, an interactive Kimi session is started for the
selected project.

Project selection:
  The project is chosen from projects.yaml.  You can skip the interactive
  prompt by exporting these variables before calling the script:

    PROJECT_NAME          Short name of the project (must match projects.yaml)
    PROJECT_ROOT_DIR      Absolute path to the project root
    PROJECT_AGENTS_DIR    Absolute path to the agents directory for AI files
                          (optional)

  When PROJECT_AGENTS_DIR is omitted — either from the environment or from
  projects.yaml — it defaults to:
    <devbox-root>/kimi-agents/<PROJECT_NAME>

Environment variables:
  USER_UID      Host user ID to use inside the container (default: current user).
  USER_GID      Host group ID to use inside the container (default: current group).
  KIMI_VERSION  Version of @moonshot-ai/kimi-code to install (default: latest).

Run with no command to start Kimi.
EOF
}

# Load the selected project from environment variables or from projects.yaml.
load_project() {
  # If name and root are exported, trust them.  PROJECT_AGENTS_DIR is optional
  # and defaults to <devbox-root>/kimi-agents/<PROJECT_NAME>.
  if [[ -n "${PROJECT_NAME:-}" && -n "${PROJECT_ROOT_DIR:-}" ]]; then
    PROJECT_AGENTS_DIR="${PROJECT_AGENTS_DIR:-$DEVBOX_ROOT/kimi-agents/${PROJECT_NAME}}"
    export PROJECT_NAME PROJECT_ROOT_DIR PROJECT_AGENTS_DIR
    return 0
  fi

  if [[ ! -f "$SELECT_PROJECT_SCRIPT" ]]; then
    echo "Error: helper script not found: $SELECT_PROJECT_SCRIPT" >&2
    return 1
  fi

  # shellcheck source=scripts/select-project.sh
  source "$SELECT_PROJECT_SCRIPT"

  local projects_yaml="$DEVBOX_ROOT/projects.yaml"
  select_project "$projects_yaml" "$DEVBOX_ROOT"

  PROJECT_NAME="$SELECTED_PROJECT_NAME"
  PROJECT_ROOT_DIR="$SELECTED_PROJECT_ROOT"
  PROJECT_AGENTS_DIR="$SELECTED_PROJECT_AGENTS"
  export PROJECT_NAME PROJECT_ROOT_DIR PROJECT_AGENTS_DIR
}

# Ensure the project root exists and the agents directory can be created.
ensure_paths() {
  if [[ ! -d "$PROJECT_ROOT_DIR" ]]; then
    echo "Error: project root does not exist: $PROJECT_ROOT_DIR" >&2
    return 1
  fi

  mkdir -p "$PROJECT_AGENTS_DIR"
}

run_container() {
  # Use a project-specific Compose project name so multiple projects can run
  # at the same time without container-name collisions.
  exec docker compose \
    --file "$COMPOSE_FILE" \
    --project-name "kimi-${PROJECT_NAME}" \
    run --rm "$SERVICE_NAME" "$@"
}

# Make sure the persistent home parent directory exists before compose tries to
# mount it.
mkdir -p "$DEVBOX_ROOT/.docker_data/kimi-home"

if [[ "$#" -gt 0 ]]; then
  case "$1" in
    help|-h|--help)
      show_help
      exit 0
      ;;

    build)
      exec docker compose --file "$COMPOSE_FILE" build "$SERVICE_NAME"
      ;;

    shell)
      load_project
      ensure_paths
      run_container bash
      ;;

    *)
      load_project
      ensure_paths
      run_container "$@"
      ;;
  esac
fi

# Default: start an interactive Kimi session.
load_project
ensure_paths

# Build only if the image does not already exist. Run `./run-kimi.sh build` to
# force a rebuild after changing the Dockerfile or context.
image_name=$(docker compose --file "$COMPOSE_FILE" --project-name "kimi-${PROJECT_NAME}" config --images | awk -v svc="$SERVICE_NAME" '$1 == svc {print $2}')
if [[ -z "$image_name" ]] || ! docker image inspect "$image_name" >/dev/null 2>&1; then
  docker compose --file "$COMPOSE_FILE" --project-name "kimi-${PROJECT_NAME}" build "$SERVICE_NAME"
fi

run_container
