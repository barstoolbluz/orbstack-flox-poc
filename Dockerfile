# Production Dockerfile — Flox-informed containerization
#
# This Dockerfile mirrors the runtime declared in the Flox manifest:
#   - Ruby 3.4.x (from Flox: ruby.pkg-path = "ruby")
#   - PostgreSQL client libs (from Flox: postgresql.pkg-path = "postgresql")
#   - libyaml (from Flox: libyaml.pkg-path = "libyaml")
#
# The Flox manifest is the source of truth for WHAT the app needs.
# This Dockerfile is the packaging step for HOW it ships to production.
#
# What Flox specifies → what this Dockerfile mirrors:
#   ruby 3.4           → ruby:3.4-slim base image
#   postgresql (client) → libpq-dev build dep, libpq5 runtime dep
#   libyaml             → libyaml-dev build dep
#   gcc, gnumake        → build-essential (build stage only)

# --- Build stage ---
FROM ruby:3.4-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libyaml-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment true && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4

COPY . .

# --- Runtime stage ---
FROM ruby:3.4-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libyaml-0-2 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home appuser
WORKDIR /app

COPY --from=build /app /app
COPY --from=build /usr/local/bundle /usr/local/bundle

RUN chown -R appuser:appuser /app
USER appuser

ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
