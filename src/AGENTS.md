# Agent Guide

This file is written for AI coding agents. It describes how to work inside this
repository. Read `INSTRUCTIONS.md` first; it is the authoritative project
definition.

## First Steps

1. Read `src/INSTRUCTIONS.md` in full.
2. Read `src/AGENTS.md` (this file).
3. If `src/INSTRUCTIONS.md` still contains `TODO` placeholders, conflicting
   requirements, or missing details, **ask the user for clarification before
   writing code**. The user can also run `/init-project` to fill in the
   boilerplate interactively; that skill also customises the Docker environment
   and CI workflow.

## General Behaviour

- **Understand before acting.** Do not assume language, framework, or library
  availability just because it is common. Check the manifest, lockfile, or
  neighbouring files first.
- **Make minimal changes.** Solve the stated problem with the smallest possible
  diff. Avoid opportunistic refactors, renames, or formatting changes.
- **Follow existing conventions.** Match the surrounding code's naming,
  structure, comment density, and error-handling style.
- **Keep boundaries clean.** External effects (processes, network, filesystem,
  databases) should live behind interfaces or traits so the project remains
  testable without real dependencies.
- **Handle errors explicitly.** Avoid unguarded panics, `unwrap()`, `expect()`,
  or swallowed exceptions in production paths. Make errors actionable.
- **Treat input as untrusted.** Parse and validate files, network payloads, CLI
  arguments, environment variables, and user configuration defensively.
- **Test what you build.** Run the project's formatter, linter, type checker,
  and test suite after changes. Do not mark work complete while checks are red.
- **Update documentation.** When behaviour changes, update comments, docstrings,
  README sections, and `INSTRUCTIONS.md` if the change affects the project
  definition.
- **No silent dependency additions.** Before adding a package, crate, module, or
  tool, confirm the project already uses it or ask the user.
- **Security awareness.** Do not execute untrusted shell strings, do not expose
  secrets, and validate paths and identifiers before use.

## When to Ask the User

Ask for clarification when:

- `INSTRUCTIONS.md` is incomplete, ambiguous, or contains placeholders.
- A requirement conflicts with an existing implementation or another requirement.
- The best implementation is unclear or requires a trade-off.
- You are about to add a new dependency, change a public API, or restructure
  the project.
- Tests fail in a way that suggests the requirements need adjustment.

## Environment

- Development happens inside the Docker container started by `./run-kimi.sh`.
- All Kimi CLI sessions should run through `./run-kimi.sh` so the environment is
  reproducible.
- Customize the container in `.docker/Dockerfile` and `.docker/compose.yaml`
  when the project needs a specific toolchain.
