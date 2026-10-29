#!/usr/bin/env bash
set -euo pipefail

# Launcher for the Dockerised Kimi Code CLI.

DEVBOX_ROOT="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$DEVBOX_ROOT/.docker/compose.yaml"
PROJECT_COMPOSE_FILE="$DEVBOX_ROOT/.docker/compose.project.yaml"
SERVICE_NAME="isolated-kimi-cli"
SELECT_PROJECT_SCRIPT="$DEVBOX_ROOT/scripts/select-project.sh"
IMAGE_NAME="kimi-cli-devbox:latest"

export DEVBOX_ROOT
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
      Build (or rebuild) the shared Docker image. No project selection needed.

  build-project
      Build the selected project's Compose service and its Kimi image.

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
  The project is chosen from projects.yaml. You can skip the interactive
  prompt by exporting these variables before calling the script:

    PROJECT_NAME          Short name of the project (must match projects.yaml)
    PROJECT_ROOT_DIR      Absolute path to the project root
    PROJECT_AGENTS_DIR    Absolute path to the agents directory for AI files
                          (optional)

  When PROJECT_AGENTS_DIR is omitted it defaults to:
    <devbox-root>/kimi-agents/<PROJECT_NAME>

  Compose-based projects can additionally set PROJECT_SERVICE,
  PROJECT_COMPOSE_PROJECT, PROJECT_COMPOSE_FILES, and PROJECT_ENV_FILES.
  The two file-list variables contain one path per line; relative paths are
  resolved against PROJECT_ROOT_DIR.

Environment variables:
  USER_UID      Host user ID to use inside the container (default: current user).
  USER_GID      Host group ID to use inside the container (default: current group).
  KIMI_VERSION  Version of @moonshot-ai/kimi-code to install (default: latest).

Run with no command to start Kimi.
EOF
}

load_project() {
  if [[ -n "${PROJECT_NAME:-}" && -n "${PROJECT_ROOT_DIR:-}" ]]; then
    PROJECT_AGENTS_DIR="${PROJECT_AGENTS_DIR:-$DEVBOX_ROOT/kimi-agents/${PROJECT_NAME}}"
    PROJECT_SERVICE="${PROJECT_SERVICE:-}"
    PROJECT_COMPOSE_PROJECT="${PROJECT_COMPOSE_PROJECT:-}"
    PROJECT_COMPOSE_FILES="${PROJECT_COMPOSE_FILES:-}"
    PROJECT_ENV_FILES="${PROJECT_ENV_FILES:-}"
    export PROJECT_NAME PROJECT_ROOT_DIR PROJECT_AGENTS_DIR
    export PROJECT_SERVICE PROJECT_COMPOSE_PROJECT PROJECT_COMPOSE_FILES PROJECT_ENV_FILES
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
  PROJECT_SERVICE="$SELECTED_PROJECT_SERVICE"
  PROJECT_COMPOSE_PROJECT="$SELECTED_PROJECT_COMPOSE_PROJECT"
  PROJECT_COMPOSE_FILES="$SELECTED_PROJECT_COMPOSE_FILES"
  PROJECT_ENV_FILES="$SELECTED_PROJECT_ENV_FILES"
  export PROJECT_NAME PROJECT_ROOT_DIR PROJECT_AGENTS_DIR
  export PROJECT_SERVICE PROJECT_COMPOSE_PROJECT PROJECT_COMPOSE_FILES PROJECT_ENV_FILES
}

ensure_paths() {
  if [[ ! -d "$PROJECT_ROOT_DIR" ]]; then
    echo "Error: project root does not exist: $PROJECT_ROOT_DIR" >&2
    return 1
  fi

  mkdir -p "$PROJECT_AGENTS_DIR"
  mkdir -p "$DEVBOX_ROOT/.docker_data/kimi-home/$PROJECT_NAME"
}

set_terminal_title() {
  if [[ -w /dev/tty ]]; then
    { printf '\033]0;kimi: %s\007' "$PROJECT_NAME" > /dev/tty; } 2>/dev/null || true
  fi
}

absolute_project_path() {
  local path="$1"
  if [[ "$path" != /* ]]; then
    path="$PROJECT_ROOT_DIR/$path"
  fi
  printf '%s' "$path"
}

configure_compose() {
  PROJECT_COMPOSE_ARGS=()
  KIMI_COMPOSE_ARGS=()
  PROJECT_RUN_ARGS=(--rm)

  if [[ -z "$PROJECT_COMPOSE_FILES" ]]; then
    if [[ -n "$PROJECT_SERVICE" || -n "$PROJECT_COMPOSE_PROJECT" || -n "$PROJECT_ENV_FILES" ]]; then
      echo "Error: Compose options require PROJECT_COMPOSE_FILES" >&2
      return 1
    fi

    KIMI_COMPOSE_ARGS=(
      --file "$COMPOSE_FILE"
      --project-name "kimi-${PROJECT_NAME}"
    )
    return 0
  fi

  if [[ -z "$PROJECT_SERVICE" ]]; then
    echo "Error: service is required when compose_files is configured" >&2
    return 1
  fi

  PROJECT_COMPOSE_PROJECT="${PROJECT_COMPOSE_PROJECT:-$PROJECT_NAME}"
  export PROJECT_COMPOSE_PROJECT
  PROJECT_RUN_ARGS+=(--no-deps)

  PROJECT_COMPOSE_ARGS=(
    --project-directory "$PROJECT_ROOT_DIR"
    --project-name "$PROJECT_COMPOSE_PROJECT"
  )

  local file absolute_path
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    absolute_path="$(absolute_project_path "$file")"
    if [[ ! -f "$absolute_path" ]]; then
      echo "Error: env file does not exist: $absolute_path" >&2
      return 1
    fi
    PROJECT_COMPOSE_ARGS+=(--env-file "$absolute_path")
  done <<< "$PROJECT_ENV_FILES"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    absolute_path="$(absolute_project_path "$file")"
    if [[ ! -f "$absolute_path" ]]; then
      echo "Error: Compose file does not exist: $absolute_path" >&2
      return 1
    fi
    PROJECT_COMPOSE_ARGS+=(--file "$absolute_path")
  done <<< "$PROJECT_COMPOSE_FILES"

  KIMI_COMPOSE_ARGS=(
    "${PROJECT_COMPOSE_ARGS[@]}"
    --file "$PROJECT_COMPOSE_FILE"
  )
}

resolve_project_image() {
  local image
  if ! image="$(docker compose "${PROJECT_COMPOSE_ARGS[@]}" config --images "$PROJECT_SERVICE")"; then
    echo "Error: could not resolve image for Compose service '$PROJECT_SERVICE'" >&2
    return 1
  fi

  if [[ -z "$image" || "$image" == *$'\n'* ]]; then
    echo "Error: expected one image for Compose service '$PROJECT_SERVICE', got:" >&2
    printf '%s\n' "${image:-<none>}" >&2
    return 1
  fi

  PROJECT_BASE_IMAGE="$image"
  KIMI_PROJECT_IMAGE="kimi-${PROJECT_NAME}:latest"
  export PROJECT_BASE_IMAGE KIMI_PROJECT_IMAGE
}

build_image() {
  docker build \
    --build-arg "KIMI_VERSION=${KIMI_VERSION}" \
    --tag "$IMAGE_NAME" \
    --no-cache \
    "$DEVBOX_ROOT/.docker"
}

build_kimi_project_image() {
  docker compose "${KIMI_COMPOSE_ARGS[@]}" build --no-cache "$SERVICE_NAME"
}

build_project() {
  if [[ -z "$PROJECT_COMPOSE_FILES" ]]; then
    echo "Error: project '$PROJECT_NAME' has no compose_files configuration" >&2
    return 1
  fi

  configure_compose
  docker compose "${PROJECT_COMPOSE_ARGS[@]}" build "$PROJECT_SERVICE"
  resolve_project_image
  build_kimi_project_image
}

prepare_image() {
  configure_compose

  if [[ -z "$PROJECT_COMPOSE_FILES" ]]; then
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
      build_image
    fi
    return 0
  fi

  resolve_project_image
  if ! docker image inspect "$KIMI_PROJECT_IMAGE" >/dev/null 2>&1; then
    echo "Building $KIMI_PROJECT_IMAGE from $PROJECT_BASE_IMAGE"
    echo "Run './run-kimi.sh build-project' after changing the project image."
    build_kimi_project_image
  fi
}

run_container() {
  set_terminal_title
  exec docker compose \
    "${KIMI_COMPOSE_ARGS[@]}" \
    run "${PROJECT_RUN_ARGS[@]}" "$SERVICE_NAME" "$@"
}

launch_project() {
  load_project
  ensure_paths
  prepare_image
  run_container "$@"
}

mkdir -p "$DEVBOX_ROOT/.docker_data/kimi-home"

if [[ "$#" -gt 0 ]]; then
  case "$1" in
    help|-h|--help)
      show_help
      exit 0
      ;;

    build)
      build_image
      exit
      ;;

    build-project)
      load_project
      ensure_paths
      build_project
      exit
      ;;

    shell)
      launch_project bash
      ;;

    *)
      launch_project "$@"
      ;;
  esac
fi

launch_project
