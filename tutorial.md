# On the Unnecessary Containerization of Development Runtimes

There is a pattern that has become pervasive in our industry, and like many pervasive patterns, it persists not because it is good but because it is familiar. The pattern is this: wrap your entire development environment — language runtime, libraries, tools, and all — in a Docker container, then mount your source code into it and pretend that the resulting arrangement is ergonomic. It is not. It is slow to build, opaque to debug, and it introduces a layer of indirection between the developer and their application that yields remarkably little in return.

The interesting question is not whether containers are useful (they obviously are) but where the boundary ought to fall. We containerize the runtime because we want reproducibility, but we pay for it with rebuild cycles and filesystem abstractions that fight us at every turn. Meanwhile, the thing that actually benefits from containerization — the stateful service, the database with its volumes and lifecycle concerns — is often left as an exercise for the reader.

What follows is a walkthrough that draws the boundary differently: [Flox](https://flox.dev) manages the application runtime; Docker manages the database. We will build a Rails API backed by PostgreSQL, though the specific technology stack matters less than the structural principle.

## Setting up the Flox environment

Begin by [installing Flox](https://flox.dev/docs/install-flox/) if you haven't already, then initialize an environment in your project directory:

```bash
flox init
```

This creates a `.flox/` directory containing the manifest at `.flox/env/manifest.toml`. Open it with `flox edit` and build up the `[install]` section — or, if you prefer working incrementally, add packages one at a time with `flox install ruby`, `flox install postgresql`, and so on. Either way, you arrive at the same place:

```toml
[install]
ruby.pkg-path = "ruby"               # Ruby 3.4.x
postgresql.pkg-path = "postgresql"    # Client libs + psql CLI
libyaml.pkg-path = "libyaml"         # Required by psych gem
gcc.pkg-path = "gcc"                  # Native gem extensions
gnumake.pkg-path = "gnumake"         # Make for gem builds
pkg-config.pkg-path = "pkg-config"   # Finds library paths
gum.pkg-path = "gum"                 # Styled terminal output
coreutils.pkg-path = "coreutils"     # GNU coreutils (macOS compat)
gnused.pkg-path = "gnused"           # GNU sed (macOS compat)
```

Nine lines, and it is the entire dependency surface of the application. Every developer who runs `flox activate` gets the same Ruby, the same PostgreSQL client libraries, the same libyaml — regardless of whether they are on an M3 MacBook or an x86 Linux workstation. There is no Homebrew to drift, no system-level installation to remember, no `README` section titled "Prerequisites" that is perpetually out of date.

The manifest also has a `[hook]` section where you configure the runtime. Use `flox edit` to add environment variables with overridable defaults:

```bash
export DATABASE_HOST="${DATABASE_HOST:-localhost}"
export DATABASE_PORT="${DATABASE_PORT:-5432}"
export DATABASE_USER="${DATABASE_USER:-postgres}"
```

A developer who needs to point at a different database simply writes `DATABASE_HOST=10.0.1.5 flox activate`. The rest of the hook — gem path setup, dependency installation, a status banner — follows the same pattern of modular, idempotent functions that do their work and get out of the way.

## The database stays in Docker

PostgreSQL, by contrast, belongs in a container. It is a stateful service with its own lifecycle: it needs persistent volumes, initialization scripts, health checks, and a clean-reset workflow. Docker handles all of this well, and there is no reason to reinvent it. Create a `docker-compose.yml` alongside the manifest:

```yaml
services:
  postgres:
    image: postgres:17-alpine
    container_name: flox-poc-postgres
    ports:
      - "${DATABASE_PORT:-5432}:5432"
    environment:
      POSTGRES_USER: ${DATABASE_USER:-postgres}
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD:-postgres}
      POSTGRES_DB: flox_rails_poc_development
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./db/init:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 5
```

Notice that the same `DATABASE_*` variables appear in both the Flox hook and the compose file. The two configurations share a vocabulary without sharing a mechanism, which is the right kind of coupling: semantic, not structural.

## Continuous integration as a consequence

If the manifest is genuinely the source of truth for the runtime, then CI should consume it directly rather than maintaining a parallel definition. The GitHub Actions workflow does exactly this:

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Install Flox
    uses: flox/install-flox-action@2

  - name: Install dependencies via Flox
    run: flox activate -- bundle install

  - name: Setup database
    run: flox activate -- bundle exec rails db:create db:migrate
    env:
      RAILS_ENV: test
      DATABASE_HOST: localhost

  - name: Run tests
    run: flox activate -- bundle exec rails test
    env:
      RAILS_ENV: test
      DATABASE_HOST: localhost
```

There is no `ruby-setup` action, no version matrix, no `.tool-versions` file to keep in sync. The manifest pins the Ruby version; `flox activate` provides it. PostgreSQL runs as a GitHub Actions service container — the same structural split as local development, transposed onto a different substrate.

## The production container, informed but not generated

The production Dockerfile does not use Flox. This is deliberate. A production container has different constraints — minimal surface area, multi-stage builds, no development tooling — and it would be dishonest to pretend that the manifest can be mechanically translated into a Dockerfile. What the manifest provides is a clear, inspectable record of what the application needs, which makes the Dockerfile easier to write and keep aligned:

```dockerfile
# What Flox specifies → what this Dockerfile mirrors:
#   ruby 3.4           → ruby:3.4-slim base image
#   postgresql (client) → libpq-dev build dep, libpq5 runtime dep
#   libyaml             → libyaml-dev build dep
#   gcc, gnumake        → build-essential (build stage only)
```

The build stage pulls in `build-essential`, `libpq-dev`, and `libyaml-dev` for gem compilation; the runtime stage keeps only `libpq5` and `libyaml-0-2`. Developer tools like `gum` and `gnused` are absent entirely, as they should be.

## What does not map cleanly

Nix package names and Debian package names are different vocabularies: Flox calls it `libyaml`; the Dockerfile needs `libyaml-dev` for build and `libyaml-0-2` for runtime. You maintain that translation by hand. Transitive dependencies diverge as well — Nix packages carry their full closure, while Debian's package manager resolves its own dependency graph. The build toolchain is another seam: Flox provides `gcc` and `gnumake` as discrete packages; the Dockerfile uses `build-essential` and discards it in a later stage.

These are real costs. The value of the pattern is not that it eliminates the gap between development and production — nothing does — but that it makes the development side explicit and inspectable, so that the production side is easier to get right.

## Try it

The complete project is [on GitHub](https://github.com/YOURUSER/orbstack-flox-poc). Clone it, run `flox activate`, bring up the database with `scripts/db-up`, and start the Rails server with `scripts/dev`. The broader point is architectural: draw the containerization boundary where it actually helps, and leave it alone where it doesn't.
