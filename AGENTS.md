# Agent Guide

This is the authoritative project definition for the **kimi-cli-devbox**
launcher itself.  AI coding agents should read this file before making changes.

## Project Name

`kimi-cli-devbox` — external Kimi Code CLI launcher.

## Overview

This repository is a Docker-based control centre for the Kimi Code CLI.  Instead
of copying boilerplate into every project you work on, you keep this launcher in
one place — for example `/opt/develop/isolated-kimi-cli` — and point it at your
projects via `projects.yaml`.  When you run `./run-kimi.sh`, the launcher asks
which project to open and mounts the project root plus a separate agents
directory into the container.

The target project directory is never modified by the launcher on the host.
The only exception is the empty `.kimi-code` mountpoint directory that Docker
creates at the project root for the agents-directory bind mount.  AI-related
files themselves live in the agents directory, which is mounted as
`/workspace/.kimi-code` inside the container.  Kimi runtime data (sessions,
config, credentials) is isolated per project under
`.docker_data/kimi-home/<project-name>`.

## Goals

1. Provide a single, reusable Docker environment for Kimi CLI development.
2. Mount arbitrary project roots dynamically without copying the devbox into
   them.
3. Keep AI instructions and agents in a directory that is separate from the
   actual project source.
4. Keep the implementation minimal and host-dependency-free — YAML parsing is
   done with pure shell so Python or `yq` is not required on the host.

## Constraints and Assumptions

- **Target platform:** Linux (the container host).  macOS/Windows may work with
  adjustments but are not explicitly supported.
- **Language / runtime:** Bash, Docker, Docker Compose.
- **Key tools:** Alpine Linux base image, `npm` for installing Kimi CLI.
- **Hard constraints:** No host dependency beyond Bash, Docker, and standard
  POSIX utilities.  The target project root must be a directory on the host.

## Functional Requirements

### 1. Project list

- `projects.yaml` stores a list of projects.  It is gitignored.
- `projects.yaml.example` is committed as documentation and a starting point.
- Each project has a required `name` and `root`, plus an optional `agents`
  directory.
- `name` must contain only lowercase letters, digits, underscores, and hyphens.
- If `agents` is omitted, it defaults to `<devbox-root>/kimi-agents/<name>`.

### 2. Project selection

- `run-kimi.sh` presents a numbered menu parsed from `projects.yaml`.
- Selection can be bypassed by exporting `PROJECT_NAME`, `PROJECT_ROOT_DIR`, and
  `PROJECT_AGENTS_DIR`.

### 3. Container mounts

- `$PROJECT_ROOT_DIR` is mounted at `/workspace`.
- `$PROJECT_AGENTS_DIR` is mounted at `/workspace/.kimi-code`.
- The Kimi home base is mounted at `/home/kimi`; the actual Kimi data directory
  is a per-project subdirectory selected by `PROJECT_NAME`.
- Before the container starts, `run-kimi.sh` sets the terminal window/tab
  title to `kimi: <PROJECT_NAME>` via an OSC escape written to `/dev/tty`.

### 4. AI file discovery

- The launcher never creates files or symlinks in the project root.  Kimi
  discovers the agents directory via the `/workspace/.kimi-code` mount; a
  root-level `AGENTS.md` must live in the project repository itself.

### 5. Docker image

- All projects share a single image tagged `kimi-cli-devbox:latest`
  (the `image:` key in `.docker/compose.yaml`).
- `./run-kimi.sh build` builds it with plain `docker build` — no project
  selection required.  The default run path builds it only if missing.

## Non-Functional Requirements

- **Code quality:** Scripts pass `shellcheck` and handle malformed config
  gracefully with clear error messages.
- **Testability:** The YAML parser/selector can be exercised independently via
  `./scripts/select-project.sh <file>`.
- **No host deps:** The launcher does not require Python, Node, or `yq` on the
  host.
- **Observability:** `run-kimi.sh --help` and parser errors explain what the
  user needs to do.

## Development Standards

- No speculative abstractions; keep modules focused and boundaries explicit.
- Handle errors explicitly; avoid unguarded failures.
- Treat all external input (the YAML file, paths, environment variables) as
  untrusted and validate it.
- Match the existing script style and conventions.
- Run `shellcheck` on changed scripts before considering work done.

## Project Layout

```
/                         # devbox repository root (can live anywhere, e.g. /opt/develop/isolated-kimi-cli)
├── projects.yaml.example # example project list
├── projects.yaml         # per-machine project list (gitignored)
├── run-kimi.sh           # launcher entry point
├── scripts/
│   └── select-project.sh # pure-shell YAML parser and selector
├── AGENTS.md             # this file — project definition for the launcher
├── .docker/
│   ├── Dockerfile
│   ├── compose.yaml
│   └── entrypoint.sh
└── .docker_data/
    └── kimi-home/        # per-project Kimi runtime data
```

## Development Process

1. Change scripts and configuration.
2. Run `shellcheck` on `run-kimi.sh` and `scripts/select-project.sh`.
3. Test the parser with sample `projects.yaml` files.
4. Verify container builds and mounts the expected directories.
5. Update `README.md` and this file when behaviour changes.

## When to Ask the User

Ask for clarification when:

- These instructions are incomplete, ambiguous, or contradictory.
- A requirement conflicts with an existing implementation or another requirement.
- The best implementation is unclear or requires a trade-off.
- You are about to add a new dependency, change a public API, or restructure
  the project.
- Tests fail in a way that suggests the requirements need adjustment.

## Environment

- Development happens inside the Docker container started by `./run-kimi.sh`.
- All Kimi CLI sessions for the launcher itself should run through
  `./run-kimi.sh` so the environment is reproducible.
- Customize the container in `.docker/Dockerfile` and `.docker/compose.yaml`
  when the launcher needs a specific toolchain.
