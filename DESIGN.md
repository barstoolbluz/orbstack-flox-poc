# Design Notes: Flox + OrbStack Pattern

## Why Flox manages the app/runtime layer

Flox provides a **declarative, reproducible, inspectable** definition of everything
the application needs to run: language runtime, native libraries, CLI tools, and
developer utilities. This definition lives in `manifest.toml` and is versioned
alongside the code.

Benefits:
- Every developer gets the exact same Ruby, PostgreSQL client, libyaml, and tooling
- No "works on my machine" drift between teammates or between dev and CI
- The manifest is human-readable — a new developer can see what the app needs
- No system-level package installation required; Flox environments are isolated
- Cross-platform: the same manifest works on Linux and macOS

## Why OrbStack/Docker manages the database locally

PostgreSQL is a **stateful service** with its own lifecycle:
- It needs persistent storage (volumes)
- It needs initialization (creating databases, extensions)
- It needs reset/restore workflows
- It runs as a daemon independent of the developer's shell

Docker (via OrbStack on macOS) already handles all of this well:
- Named volumes for persistence
- Init scripts via `/docker-entrypoint-initdb.d/`
- `docker compose down -v` for clean resets
- Health checks for readiness

Putting PostgreSQL in Flox services would mean:
- Managing data directory lifecycle in hooks
- Reimplementing init/reset/backup workflows
- Coupling the database lifecycle to the shell session

The database is infrastructure; the runtime is the application's concern. They
belong to different tools.

## How the Flox environment informs CI and production

### CI

The GitHub Actions workflow installs Flox and runs all commands inside
`flox activate`. This means CI uses the **exact same package set** as local
development — same Ruby version, same native libraries, same tools. There is no
separate CI configuration for the language runtime.

### Production container

The Dockerfile is **Flox-informed**, not Flox-generated:

| Flox manifest                  | Dockerfile equivalent           |
|--------------------------------|----------------------------------|
| `ruby.pkg-path = "ruby"`      | `FROM ruby:3.4-slim`            |
| `postgresql.pkg-path = ...`   | `libpq-dev` / `libpq5`         |
| `libyaml.pkg-path = ...`      | `libyaml-dev` / `libyaml-0-2`  |
| `gcc.pkg-path = "gcc"`        | `build-essential` (build stage) |

The Flox manifest is the **source of truth** for what the app needs. The
Dockerfile translates that into container packaging. When a dependency changes
in the manifest, the Dockerfile should be updated to match.

## What this pattern buys a team

1. **Onboarding in minutes**: clone, `flox activate`, `scripts/db-up`, `scripts/dev`
2. **No container overhead for development**: the app runs natively, with fast
   iteration and direct debugging
3. **Stateful services stay in Docker**: where volume management, health checks,
   and reset workflows are mature
4. **CI alignment**: Flox ensures CI runs the same runtime as local dev
5. **Production clarity**: the Dockerfile explicitly maps from the declared
   runtime, making dependency changes traceable

## Tradeoffs

### What maps cleanly from Flox to Docker
- Language runtime version
- Native library dependencies
- CLI tools needed at build time

### What does NOT map directly
- **Transitive dependencies**: Nix packages include their full closure; Docker
  images use the distro's package manager, which may resolve different versions
  of transitive deps
- **Package names**: Nix and Debian use different names (`libyaml` vs
  `libyaml-dev`/`libyaml-0-2`)
- **Build tooling**: Flox provides `gcc` and `gnumake` for gem compilation;
  Docker uses `build-essential` and discards it in a multi-stage build
- **Developer tools**: `gum`, `gnused`, etc. are dev-only and don't belong in
  production images

### The honest summary

The Flox manifest tells you **what the app needs**. The Dockerfile tells you
**how to package it**. They are not the same thing, and pretending they are would
be misleading. The value is that the manifest makes the "what" explicit and
inspectable, so the "how" is easier to get right and keep aligned.
