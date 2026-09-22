# Changelog

All notable changes to this project are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.3] - 2026-09-22

### Changed

- Upgraded the base image from `alpine:3.20` to `alpine:3.22`.
- The container image now includes `shellcheck` and `python3`.

### Removed

- Removed the bundled `init-project` skill
  (`.kimi-code/skills/init-project/SKILL.md`).

## [0.2.2] - 2026-08-14

### Removed

- The container entrypoint no longer creates `AGENTS.md`/`INSTRUCTIONS.md`
  symlinks at the workspace root.  The launcher now never modifies the project
  root (Docker may still create the empty `.kimi-code` mountpoint); a
  root-level `AGENTS.md` should live in the project repository itself.
  Stale symlinks left by previous runs are not cleaned up automatically —
  remove them manually.

## [0.2.1] - 2026-08-05

### Added

- The terminal window/tab title is set to `kimi: <PROJECT_NAME>` before the
  container starts, so concurrent sessions are easy to tell apart.

### Changed

- All projects now share a single Docker image tagged `kimi-cli-devbox:latest`;
  `./run-kimi.sh build` uses plain `docker build` and no longer requires
  project selection or Compose variable interpolation.
- Kimi runtime data is now isolated per project: each project gets its own
  home directory under `.docker_data/kimi-home/<project-name>`, mounted as
  `/home/kimi` in the container.
- The container entrypoint no longer recursively `chown`s `/workspace`; only
  the mounted Kimi home directory is adjusted.

### Fixed

- `./run-kimi.sh build` failed with "PROJECT_NAME is not set" because Compose
  interpolates mandatory variables for every subcommand.
- The build-if-missing check never matched the image produced by
  `./run-kimi.sh build` (different Compose project names produced different
  image names), causing duplicate per-project builds.
- A stale `AGENTS.md`/`INSTRUCTIONS.md` symlink from a previous run crashed the
  entrypoint (`ln -s` failing on an existing dangling link).
- Removed a duplicated `mkdir -p` in `run-kimi.sh`.
- Docs claimed the host project directory is never modified and that workspace
  symlinks exist only inside the container; both claims corrected.
- README custom-agent example was one directory level too deep
  (`.kimi-code/agents/` inside the agents directory).
- Renamed the bundled `agents.md` files to `AGENTS.md` so the entrypoint and
  Kimi can discover them.

## [0.0.1] - TODO: YYYY-MM-DD

### Added

- Initial release.
