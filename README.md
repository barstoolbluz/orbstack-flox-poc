# Flox + OrbStack/Docker: Development & Delivery Pattern

A proof of concept demonstrating how **Flox** and **OrbStack/Docker** complement
each other for local development, CI, and production containerization.

## The Pattern

| Concern | Tool | Why |
|---------|------|-----|
| Language runtime, libs, CLI tools | **Flox** | Declarative, reproducible, inspectable |
| Stateful services (PostgreSQL) | **Docker/OrbStack** | Volumes, init scripts, health checks |
| CI runtime | **Flox** (via GitHub Actions) | Same packages as local dev |
| Production packaging | **Docker** (Flox-informed) | Dockerfile mirrors declared runtime |

## What Flox does here

Flox manages the **application runtime layer**: Ruby 3.4, PostgreSQL client
libraries, libyaml, build tools (gcc, make), and developer utilities (gum).
The environment is defined in `.flox/env/manifest.toml` and activated with
`flox activate`.

Every developer gets the exact same toolchain. No Homebrew drift, no version
mismatches, no "install Ruby 3.4 and make sure you have libpq headers."

## What OrbStack/Docker does here

Docker (via OrbStack on macOS) runs **PostgreSQL** as a container with a named
volume for persistence. This is the right tool for stateful services:
`docker compose up -d` starts it, `docker compose down -v` resets it.

The application itself does **not** run in a container during development.

## What CI does here

The GitHub Actions workflow installs Flox and runs tests inside `flox activate`.
CI uses the same declared runtime as local development — no separate Ruby
version matrix or system dependency list to maintain.

## How the production container relates to the Flox runtime

The `Dockerfile` is **Flox-informed**: it mirrors the runtime declared in the
manifest using equivalent Debian packages. The mapping is explicit and documented
in the Dockerfile header. See [DESIGN.md](DESIGN.md) for the full mapping table
and tradeoff analysis.

## Why this is not either/or

- Flox replaces `rbenv` + `brew install libpq` + ad-hoc setup scripts
- Docker replaces running PostgreSQL on the host
- Neither replaces the other
- Together they give you: reproducible runtime + managed stateful services +
  clear CI alignment + traceable production packaging

## Quick Start

### Prerequisites

- [Flox](https://flox.dev/docs/install-flox/) installed
- [OrbStack](https://orbstack.dev/) (macOS) or Docker Engine (Linux)

### Setup

```bash
# 1. Clone and enter the Flox environment
git clone <this-repo> && cd orbstack-flox-poc
flox activate

# 2. Start PostgreSQL
scripts/db-up

# 3. Bootstrap the database
bundle exec rails db:create db:migrate db:seed

# 4. Run the app
scripts/dev
```

### Verify

```bash
# Health check (proves DB connectivity)
curl http://localhost:3000/health

# Create an item
curl -X POST http://localhost:3000/items \
  -H "Content-Type: application/json" \
  -d '{"item": {"name": "Hello", "description": "From Flox + Docker"}}'

# List items
curl http://localhost:3000/items
```

### All Commands

| Command | What it does |
|---------|-------------|
| `flox activate` | Enter the development environment |
| `scripts/db-up` | Start PostgreSQL container |
| `scripts/db-down` | Stop PostgreSQL container (data preserved) |
| `scripts/db-reset` | Destroy and recreate database from scratch |
| `scripts/dev` | Start Rails development server |
| `scripts/test` | Run the test suite |
| `scripts/build-image` | Build the production Docker image |

### Reset everything

```bash
scripts/db-reset          # Wipe and recreate the database
# or
docker compose down -v    # Just remove the container and volume
```

### Build production image

```bash
scripts/build-image
docker run -p 3000:3000 \
  -e DATABASE_HOST=host.docker.internal \
  -e DATABASE_USER=postgres \
  -e DATABASE_PASSWORD=postgres \
  -e SECRET_KEY_BASE=$(bundle exec rails secret) \
  flox-rails-poc
```

## How this reduces environment drift

Without Flox, a typical setup doc says: "Install Ruby 3.4, make sure you have
libpq-dev and libyaml, install Bundler, run bundle install." Each developer
interprets this differently, uses different package managers, and ends up with
subtly different environments.

With Flox, `flox activate` gives everyone the same Ruby, the same native
libraries, the same tools — resolved from the same manifest, built
reproducibly. The database still runs in Docker because that's what Docker is
good at.

## What remains container-specific

The production Dockerfile handles concerns that don't belong in Flox:
- Multi-stage builds (separating build deps from runtime)
- Non-root user creation
- Image layer optimization
- `EXPOSE` and `CMD` directives
- Debian-specific package names for the base image

These are **packaging concerns**, not runtime concerns. The Flox manifest
declares the runtime; the Dockerfile packages it for deployment.

## Repo Structure

```
.
├── .flox/                    # Flox environment (runtime declaration)
│   └── env/manifest.toml     # ← the source of truth for app dependencies
├── .github/workflows/ci.yml  # CI uses Flox for runtime alignment
├── docker-compose.yml        # PostgreSQL for local dev (OrbStack/Docker)
├── Dockerfile                # Production image (Flox-informed)
├── scripts/                  # Developer workflow commands
│   ├── dev                   # Start dev server
│   ├── db-up                 # Start PostgreSQL
│   ├── db-down               # Stop PostgreSQL
│   ├── db-reset              # Reset database
│   ├── test                  # Run tests
│   └── build-image           # Build production image
├── app/                      # Rails application
├── config/                   # Rails configuration
├── db/                       # Migrations and seeds
├── test/                     # Test suite
├── DESIGN.md                 # Architecture and tradeoff analysis
└── README.md                 # This file
```

## Further Reading

- [DESIGN.md](DESIGN.md) — detailed architecture notes and tradeoff analysis
- [Flox documentation](https://flox.dev/docs/)
- [OrbStack documentation](https://orbstack.dev/)
