# kimi-cli-devbox

A minimal, language-agnostic Docker sandbox for developing projects with the
[Kimi Code CLI](https://www.moonshot.cn/).

> **Disclaimer**
>
> This project is at an early release stage. AI agents and large language models
> are non-deterministic and may modify, overwrite, or delete files unexpectedly.
> Use this boilerplate at your own risk. Before copying it into an existing
> project or running `/init-project`, make sure you have a fresh backup of your
> repository and any important data.

## What is this?

This repository provides:

- a `run-kimi.sh` script that builds and enters a Docker container with Kimi CLI
  pre-installed;
- a generic Docker setup that you can extend with any language toolchain;
- a place (`src/INSTRUCTIONS.md`) to write the project definition so the AI has
  a single source of truth;
- a generic agent guide (`src/AGENTS.md`) that reminds the AI to ask questions
  when instructions are incomplete;
- an `/init-project` skill that interviews you and fills in the boilerplate.

## Quick start

1. Copy this boilerplate into a new repository, **or drop the `.docker/`,
   `.kimi-code/`, `src/`, and `run-kimi.sh` files into an existing project**.
2. Run `/init-project` inside Kimi to fill in the project definition
   interactively (or edit `src/INSTRUCTIONS.md` manually).
3. Customize `.docker/Dockerfile` and `.docker/compose.yaml` if your project
   needs a specific runtime, package manager, or cache directories.
4. Build and run Kimi inside the isolated container:

   ```bash
   ./run-kimi.sh build   # only needed once, or after changing the Dockerfile
   ./run-kimi.sh
   ```

5. Start building. The AI will read `src/INSTRUCTIONS.md` and
   `src/AGENTS.md` before writing code.

## Project initialization

Inside the container, run:

```bash
/init-project [project-name]
```

Kimi will ask you about the project name, overview, goals, constraints, tech
stack, requirements, Docker setup, and CI commands, then write everything into
`src/INSTRUCTIONS.md` and update `README.md`, `CHANGELOG.md`,
`.docker/Dockerfile`, `.docker/compose.yaml`, and `.github/workflows/`
accordingly.

## Useful commands

```bash
./run-kimi.sh           # start an interactive Kimi session
./run-kimi.sh build     # build (or rebuild) the Docker image
./run-kimi.sh shell     # open a shell in the container
./run-kimi.sh <command> # run any command inside the container
```

## Customising the environment

- `.docker/Dockerfile` — based on `alpine:3.20`; add language runtimes,
  compilers, package managers, and system dependencies.
- `.docker/compose.yaml` — mount project directories, caches, and persistent
  volumes. By default the repository root is mounted at `/workspace`.
- `.docker/entrypoint.sh` — runs as root to match the in-container `kimi`
  user's UID/GID to the host user, then drops privileges before starting Kimi.
- `.gitignore` — add language-specific build outputs.
- `.github/workflows/` — add CI/CD for your project.

The container runs as a non-root `kimi` user whose UID/GID are automatically
matched to the host user, so files created in `/workspace` keep the correct
ownership.

## Project files

| File | Purpose |
|------|---------|
| `src/INSTRUCTIONS.md` | **Edit this.** The project definition the AI reads first. |
| `src/AGENTS.md` | Generic guidance for the AI; add project-specific rules here. |
| `CHANGELOG.md` | Release notes. |
| `run-kimi.sh` | Entry point for the Dockerised Kimi CLI. |
| `.docker/` | Docker image, compose configuration, and runtime entrypoint. |
| `.kimi-code/skills/init-project/` | Project initialization skill (`/init-project`). |

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
