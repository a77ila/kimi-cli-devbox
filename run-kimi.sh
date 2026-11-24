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
# Base image used when a project does not set `image:` in projects.yaml.
# Keep in sync with the ARG BASE_IMAGE default in .docker/Dockerfile.
DEFAULT_BASE_IMAGE="alpine:3.22"
# Projects without a custom base image share this image; projects with a
# custom base image get their own tag (kimi-cli-devbox-<name>:latest).
DEFAULT_IMAGE_NAME="kimi-cli-devbox:latest"

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
      Build (or rebuild) the Docker image for the selected project.

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
    PROJECT_IMAGE         Base Docker image to install Kimi Code into
                          (optional, overrides the projects.yaml image key)

  When PROJECT_AGENTS_DIR is omitted — either from the environment or from
  projects.yaml — it defaults to:
    <devbox-root>/kimi-agents/<PROJECT_NAME>

Container image:
  Each project runs in an image derived from a base image.  The base image
  comes from the optional image key in projects.yaml (or PROJECT_IMAGE);
  when unset it defaults to alpine:3.22.  Kimi Code and its Node.js runtime
  are installed on top, so a project toolchain image (e.g. php:8.3-cli)
  provides composer, phpstan, phpunit, etc. out of the box.

  Projects without a custom base image share the image
  kimi-cli-devbox:latest.  Projects with a custom base image get their own
  image tagged kimi-cli-devbox-<name>:latest, rebuilt automatically when the
  base image or KIMI_VERSION changes.  The supported base images are Alpine
  and Debian/Ubuntu derivatives (anything with apk or apt-get).

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
  # and defaults to <devbox-root>/kimi-agents/<PROJECT_NAME>.  PROJECT_IMAGE is
  # optional and selects the base image Kimi Code is installed into.
  if [[ -n "${PROJECT_NAME:-}" && -n "${PROJECT_ROOT_DIR:-}" ]]; then
    PROJECT_AGENTS_DIR="${PROJECT_AGENTS_DIR:-$DEVBOX_ROOT/kimi-agents/${PROJECT_NAME}}"
    PROJECT_IMAGE="${PROJECT_IMAGE:-}"
    export PROJECT_NAME PROJECT_ROOT_DIR PROJECT_AGENTS_DIR PROJECT_IMAGE
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
  PROJECT_IMAGE="${SELECTED_PROJECT_IMAGE:-}"
  export PROJECT_NAME PROJECT_ROOT_DIR PROJECT_AGENTS_DIR PROJECT_IMAGE
}

# Decide which base image and which image tag this project uses, then export
# KIMI_IMAGE for compose.yaml.
resolve_image() {
  if [[ -n "$PROJECT_IMAGE" ]]; then
    BASE_IMAGE="$PROJECT_IMAGE"
    IMAGE_NAME="kimi-cli-devbox-${PROJECT_NAME}:latest"
  else
    BASE_IMAGE="$DEFAULT_BASE_IMAGE"
    IMAGE_NAME="$DEFAULT_IMAGE_NAME"
  fi
  export BASE_IMAGE IMAGE_NAME KIMI_IMAGE="$IMAGE_NAME"
}

# Ensure the project root exists and the agents directory can be created.
ensure_paths() {
  if [[ ! -d "$PROJECT_ROOT_DIR" ]]; then
    echo "Error: project root does not exist: $PROJECT_ROOT_DIR" >&2
    return 1
  fi

  mkdir -p "$PROJECT_AGENTS_DIR"
  mkdir -p "$DEVBOX_ROOT/.docker_data/kimi-home/$PROJECT_NAME"
}

# Show the project name in the terminal window/tab title so multiple
# concurrent Kimi sessions are easy to tell apart.  The OSC escape is sent
# to /dev/tty so it never pollutes piped command output.
set_terminal_title() {
  if [[ -w /dev/tty ]]; then
    printf '\033]0;kimi: %s\007' "$PROJECT_NAME" > /dev/tty 2>/dev/null || true
  fi
}

run_container() {
  # Use a project-specific Compose project name so multiple projects can run
  # at the same time without container-name collisions.
  set_terminal_title
  exec docker compose \
    --file "$COMPOSE_FILE" \
    --project-name "kimi-${PROJECT_NAME}" \
    run --rm "$SERVICE_NAME" "$@"
}

# Build the image with plain docker build so no Compose variable
# interpolation is required.  The base image and Kimi version are recorded as
# labels so ensure_image can detect when a rebuild is needed.
build_image() {
  docker build \
    --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
    --build-arg "KIMI_VERSION=${KIMI_VERSION}" \
    --label "kimi-cli-devbox.base-image=${BASE_IMAGE}" \
    --label "kimi-cli-devbox.kimi-version=${KIMI_VERSION}" \
    --tag "$IMAGE_NAME" \
    --no-cache \
    "$DEVBOX_ROOT/.docker"
}

# Build the project image if it is missing or was built from a different base
# image / Kimi version than the current configuration.
ensure_image() {
  local current_base current_kimi

  if ! current_base="$(docker image inspect --format \
      '{{index .Config.Labels "kimi-cli-devbox.base-image"}}' "$IMAGE_NAME" 2>/dev/null)"; then
    build_image
    return
  fi

  current_kimi="$(docker image inspect --format \
    '{{index .Config.Labels "kimi-cli-devbox.kimi-version"}}' "$IMAGE_NAME")"

  if [[ "$current_base" != "$BASE_IMAGE" || "$current_kimi" != "$KIMI_VERSION" ]]; then
    echo "Base image or Kimi version changed; rebuilding $IMAGE_NAME ..." >&2
    build_image
  fi
}

# Make sure the persistent home parent directory exists before compose tries to
# mount project-specific Kimi home directories.
mkdir -p "$DEVBOX_ROOT/.docker_data/kimi-home"

if [[ "$#" -gt 0 ]]; then
  case "$1" in
    help|-h|--help)
      show_help
      exit 0
      ;;

    build)
      load_project
      resolve_image
      build_image
      exit
      ;;

    shell)
      load_project
      resolve_image
      ensure_paths
      run_container bash
      ;;

    *)
      load_project
      resolve_image
      ensure_paths
      run_container "$@"
      ;;
  esac
fi

# Default: start an interactive Kimi session.
load_project
resolve_image
ensure_paths

# Build if the image is missing or its base image / Kimi version changed.
# Run `./run-kimi.sh build` to force a rebuild after changing the Dockerfile
# or context.
ensure_image

run_container
