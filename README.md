# kimi-cli-devbox

A self-contained Docker launcher for the [Kimi Code CLI](https://www.moonshot.cn/).
Keep this repository in one place — for example `/opt/develop/isolated-kimi-cli` —
and use it to open, analyse, and develop any other project on your filesystem
without copying anything into it.

> **Disclaimer**
>
> This project is at an early release stage. AI agents and large language models
> are non-deterministic and may modify, overwrite, or delete files unexpectedly.
> Use this launcher at your own risk. Before pointing it at an existing project,
> make sure you have a fresh backup of the repository and any important data.

## What is this?

This repository is a **control center**, not a project template:

- `projects.yaml` lists the projects you want to work on.
- `./run-kimi.sh` asks which project to open, then mounts that project into an
  isolated Docker container.
- AI files (`AGENTS.md`, `INSTRUCTIONS.md`, custom agents) live in a separate
  **agents directory** per project, so the real project stays clean.
- Kimi sessions, config, and credentials are isolated per project under
  `.docker_data/kimi-home/<project-name>`.

## Quick start

1. Clone or keep this repository anywhere, e.g. `/opt/develop/isolated-kimi-cli`.
2. Copy the example project list and edit it:

   ```bash
   cp projects.yaml.example projects.yaml
   # edit projects.yaml with your project roots and optional agents directories
   ```

3. Build the Docker image (only needed once, or after changing
   `.docker/Dockerfile`):

   ```bash
   ./run-kimi.sh build
   ```

4. Start Kimi for a project:

   ```bash
   ./run-kimi.sh
   ```

   Pick a project from the menu.  Its root becomes `/workspace` inside the
   container.

## Examples

**Example 1 — open an interactive Kimi session for a project**

```bash
cd /opt/develop/isolated-kimi-cli
./run-kimi.sh
```

You will see something like:

```
Available projects:
  1) api-service
       root:   /home/you/src/api-service
       agents: /opt/develop/isolated-kimi-cli/kimi-agents/api-service
  2) docs-site
       root:   /home/you/work/docs-site
       agents: /home/you/kimi-agents/docs-site
Select project (1-2):
```

**Example 2 — run a command inside a project without prompting**

```bash
export PROJECT_NAME=api-service
export PROJECT_ROOT_DIR="$HOME/src/api-service"
export PROJECT_AGENTS_DIR="$HOME/kimi-agents/api-service"
./run-kimi.sh npm test
```

## How it works

For the selected project:

- `$PROJECT_ROOT_DIR` is mounted at `/workspace`.
- `$PROJECT_AGENTS_DIR` is mounted at `/workspace/.kimi-code`, so Kimi reads it
  as the project-local configuration without adding files to the real project.
- The Kimi data directory is isolated under
  `.docker_data/kimi-home/<project-name>` via `KIMI_CODE_HOME`.
- The terminal window/tab title is set to `kimi: <project-name>` so concurrent
  sessions are easy to tell apart.

If the agents directory contains `AGENTS.md` or `INSTRUCTIONS.md` and the
project root does not already have those files, the container entrypoint creates
symlinks at the workspace root so Kimi can find them.  Because `/workspace` is a
bind mount of the real project, these symlinks (and the empty `.kimi-code`
mountpoint) are also visible on the host; the symlinks remain as dangling links
after the container exits and are reused on the next start.

## Project configuration

`projects.yaml` is gitignored.  Each machine keeps its own copy.

```yaml
projects:
  - name: my-app
    root: ~/src/my-app
    agents: ~/kimi-agents/my-app   # optional

  - name: another-app
    root: /absolute/path/to/another-app
    # agents defaults to <devbox-root>/kimi-agents/another-app
```

Rules:

- `name` and `root` are required.
- `name` must contain only lowercase letters, digits, underscores, and hyphens.
- If `agents` is omitted, it defaults to `<devbox-root>/kimi-agents/<name>`.
- Relative paths are resolved against the devbox repository root.
- `~` is expanded to the current user's home directory.

## AI files for a project

Put project-specific instructions and agents in the agents directory for that
project, not in the project repository itself:

```
kimi-agents/my-app/
├── AGENTS.md              # project-level agent instructions
├── INSTRUCTIONS.md        # project definition the AI reads first
└── agents/
    └── reviewer.md        # custom sub-agent
```

When the container starts, `/workspace/.kimi-code` points to this directory, so
Kimi discovers the project-level files automatically (the custom agent lands at
`/workspace/.kimi-code/agents/reviewer.md`).

## Useful commands

```bash
./run-kimi.sh            # start an interactive Kimi session for a project
./run-kimi.sh build      # build (or rebuild) the Docker image
./run-kimi.sh shell      # open a shell in the selected project's container
./run-kimi.sh <command>  # run any command inside the selected project's container
```

You can skip the interactive project prompt by exporting the selection before
running the script, as shown in Example 2 above.

## Customising the environment

- `.docker/Dockerfile` — based on `alpine:3.20`; add language runtimes,
  compilers, package managers, and system dependencies.
- `.docker/compose.yaml` — mount project directories, caches, and persistent
  volumes.  Project mounts are driven by environment variables set by
  `run-kimi.sh`.
- `.docker/entrypoint.sh` — runs as root to match the in-container `kimi`
  user's UID/GID to the host user, isolates `KIMI_CODE_HOME` per project, then
  drops privileges before starting Kimi.
- `.gitignore` — add language-specific build outputs.
- `.github/workflows/` — CI for this launcher (shellcheck, parser test, Docker
  image build).

The container runs as a non-root `kimi` user whose UID/GID are automatically
matched to the host user, so files created in `/workspace` keep the correct
ownership.

## Project files

| File | Purpose |
|------|---------|
| `projects.yaml.example` | Example project list. Copy to `projects.yaml` and edit. |
| `AGENTS.md` | Project definition and agent guide for this launcher itself. |
| `CHANGELOG.md` | Release notes. |
| `run-kimi.sh` | Entry point that selects and mounts a project. |
| `scripts/select-project.sh` | Pure-shell parser and menu for `projects.yaml`. |
| `.docker/` | Docker image, compose configuration, and runtime entrypoint. |

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
  <http://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or
  <http://opensource.org/licenses/MIT>)

at your option.

Unless you explicitly state otherwise, any contribution intentionally
submitted for inclusion in the work by you, as defined in the Apache-2.0
license, shall be dual licensed as above, without any additional terms or
conditions.
