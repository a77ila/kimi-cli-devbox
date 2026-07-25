# Project Instructions

> **Edit this file to define your project.**
>
> This is the single source of truth the AI uses to understand what to build.
> Replace every placeholder and TODO with real information before starting work.
> Keep the file up to date as the project evolves.

---

## Project Name

`TODO: your-project-name`

## Overview

TODO: one or two paragraphs describing what the project does, who it is for,
and why it exists.

## Goals

1. TODO: primary goal.
2. TODO: secondary goal.
3. TODO: another goal.

## Constraints and Assumptions

- **Target platform / OS:** TODO (e.g. Linux, cross-platform, browser, embedded).
- **Language / runtime:** TODO (e.g. Rust, Python 3.12, Node 20, Go 1.22).
- **Key tools or frameworks:** TODO (e.g. Cargo, uv, npm, Docker, PostgreSQL).
- **Hard constraints:** TODO (e.g. must work offline, <100 MB binary, no cloud deps).

## Functional Requirements

### 1. TODO: feature area

- TODO: requirement.
- TODO: requirement.

### 2. TODO: feature area

- TODO: requirement.
- TODO: requirement.

## Non-Functional Requirements

- **Code quality:** TODO (e.g. production-grade, reviewed, no warnings).
- **Performance:** TODO (e.g. startup <1 s, handles 10k requests/s).
- **Testability:** TODO (e.g. unit tests, integration tests, no host deps).
- **Observability:** TODO (e.g. structured logging, metrics, actionable errors).

## Development Standards

- No speculative abstractions; keep modules focused and boundaries explicit.
- Handle errors explicitly; avoid panics / unguarded exceptions in production paths.
- Treat all external input (files, network, CLI args, environment) as untrusted.
- Keep external effects injectable so tests do not need real services.
- Match the project's existing style, naming, and tooling.
- Run the project's formatter, linter, and test suite before considering work done.

## Project Layout

TODO: describe the directory structure and what lives where.

Example:

```
src/                  # application source
├── ...
tests/                # integration tests
docs/                 # additional documentation
```

## Development Process

1. **Phase 1 — TODO:** ...
2. **Phase 2 — TODO:** ...
3. **Phase 3 — TODO:** ...

## Notes for the AI

- If these instructions are incomplete or contradictory, **ask the user for
  clarification before implementing**.
- Ask before adding new dependencies, changing the public interface, or making
  large architectural decisions.
- Update this file when a decision changes the project direction.
