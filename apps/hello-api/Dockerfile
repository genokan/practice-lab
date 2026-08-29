# syntax=docker/dockerfile:1.7
ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.2.4
ARG DEBIAN_VERSION=bookworm-20260824-slim

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION} AS build

WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

# Keep dependency resolution in its own layer. BuildKit cache mounts accelerate
# unchanged rebuilds locally and in the GitHub Actions cache backend.
COPY mix.exs mix.lock* ./
RUN --mount=type=cache,target=/root/.cache/hex \
    --mount=type=cache,target=/root/.cache/rebar3 \
    mix deps.get --only $MIX_ENV

COPY config config
RUN mix deps.compile

COPY lib lib
RUN mix compile

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
RUN mix release

FROM debian:${DEBIAN_VERSION} AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      libstdc++6 \
      libncurses6 \
      libssl3 \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system app && useradd --system --gid app --home-dir /app app
WORKDIR /app
COPY --from=build --chown=app:app /app/_build/prod/rel/hello_elixir ./

USER app
ENV HOME=/app \
    PORT=4000 \
    PHX_SERVER=true

EXPOSE 4000
CMD ["/app/bin/hello_elixir", "start"]
