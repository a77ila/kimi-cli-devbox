---
name: init-project
description: Initialize a new project from the boilerplate by interviewing the user and writing src/INSTRUCTIONS.md, README.md, CHANGELOG.md, Docker, and CI configuration
type: prompt
whenToUse: When the user wants to initialize a new project from the boilerplate or set up the project definition
arguments:
  - name
---

You are initializing a new project from the kimi-cli-devbox boilerplate.

Goal: collect enough information from the user to populate `src/INSTRUCTIONS.md`,
customise the Docker environment, and set up CI. Then update `README.md` and
`CHANGELOG.md` to match. Do **not** implement the project yet.

If `$name` was provided when the skill was invoked (e.g. `/init-project my-app`),
use it as the default project name; otherwise ask for the name first.

Use the `AskUserQuestion` tool to interview the user. Ask the questions in small
batches (1-4 at a time) so the conversation stays manageable. Cover these topics:

1. **Project context** — is this a brand-new repository, or are you adding the
   kimi-cli-devbox to an existing project? If existing, ask the user to confirm
   which files (if any) must not be overwritten.
2. **Project name**
3. **Overview** — one paragraph describing what the project does and why it exists
4. **Goals** — 3-5 bullet points of what the project should achieve
5. **Target platform / OS**
6. **Language / runtime**
7. **Key tools, frameworks, package managers, or databases**
8. **Hard constraints** — performance, security, offline, size, compatibility, etc.
9. **Functional requirements** — main feature areas or user-facing capabilities
10. **Non-functional requirements** — code quality, performance, testability, observability
11. **Development standards** — any rules the AI should follow (error handling, testing, style)
12. **Project layout** — where source, tests, docs, and config should live
13. **Development phases** — high-level milestones, if known
14. **Alpine version** — the default base image is `alpine:3.20`; confirm this
    version or specify another pinned version (e.g. `alpine:3.21`).
15. **System packages** — any packages the build/runtime needs beyond the base image
16. **Language toolchain** — compiler, runtime, package manager, linter, formatter to install
17. **Persistent caches** — directories that should be mounted from `.docker_data/` so they
    survive container rebuilds (e.g. language package registries, build caches)
18. **CI checks** — commands the GitHub Actions workflow should run (e.g. `cargo test`,
    `npm run lint && npm test`)

After collecting the answers:

- If the user is adding the devbox to an **existing project**, first inspect the
  repo for existing files (e.g. `README.md`, `CHANGELOG.md`, `package.json`,
  `Cargo.toml`, `pyproject.toml`, `Makefile`, `.github/workflows/*`) and infer
  the tech stack and layout from them. Ask before overwriting any file that
  already contains project-specific content.
- When documenting **project layout**, do not assume source code lives in `src/`
  if the existing project already uses a different convention. Record the actual
  layout in `src/INSTRUCTIONS.md`.
- Replace every `TODO` placeholder in `src/INSTRUCTIONS.md` with the collected
  information. Keep the file structure, section headings, and instructions to
  the AI intact.
- Update `README.md`:
  - For a **new project**, replace the generic title and first paragraph with
    project-specific content, while keeping the "Quick start", "Useful commands",
    and "Customising the environment" sections.
  - For an **existing project**, preserve the existing README and add a
    "Developing with Kimi" section (or similar) that documents `./run-kimi.sh`,
    the devbox commands, and any project-specific container workflows. Do not
    overwrite existing project documentation.
- Update `CHANGELOG.md`:
  - For a **new project**, if the user mentioned a planned first release, add
    those items under `[Unreleased]`; otherwise leave the placeholder as is.
  - For an **existing project**, add a bullet under `[Unreleased]` noting that
    the Kimi devbox was added (e.g. "Added Dockerized Kimi CLI development
    environment via kimi-cli-devbox"). Do not discard existing changelog
    entries.
- Update `.docker/Dockerfile`:
  - Pin the `FROM` image to the requested Alpine version (e.g. `alpine:3.20`).
  - Add the requested system packages to the install step.
  - Install the requested language runtime / toolchain.
  - Keep the Kimi CLI installation using the `KIMI_VERSION` build arg
    (`npm install -g @moonshot-ai/kimi-code@${KIMI_VERSION}`), and keep the
    `WORKDIR /workspace` / `CMD ["kimi"]` lines.
- Update `.docker/compose.yaml`:
  - Keep the repository root mount and the `.docker_data/kimi-home:/home/kimi` volume.
  - Add one volume mount per persistent cache the user requested, pointing into
    `.docker_data/<cache-name>` on the host.
- Ensure the `.docker_data/` directory structure exists:
  - Create `.docker_data/kimi-home/` and any cache directories referenced in
    `.docker/compose.yaml` if they are missing.
  - Do this on the host filesystem from inside the container (the repo root is
    mounted at `/workspace`).
- Update `.github/workflows/check.yml`:
  - For a **new project**, replace the placeholder workflow with a real CI
    workflow that checks out the repo, installs any required toolchain (or runs
    inside the project Docker image), runs the CI commands the user provided,
    and keeps a simple format/lint/test structure by default.
  - For an **existing project**, if a workflow file already exists, add a
    devbox-specific job or step to it rather than replacing the whole file,
    unless the user explicitly asks to overwrite it.

Confirm the updated files with the user before finishing.
