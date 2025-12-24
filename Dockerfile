FROM elixir:1.15-alpine AS builder

RUN apk add --no-cache build-base git npm

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy config before assets (needed for asset building)
COPY config ./config

# Copy lib before assets (needed for phoenix-colocated components)
COPY lib ./lib
COPY priv ./priv

RUN mix compile

COPY assets/package.json assets/package-lock.json ./assets/
RUN cd assets && npm ci

COPY assets ./assets

RUN mix assets.deploy
RUN mix release

FROM alpine:3.19.0 AS runner

RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    libstdc++ \
    ca-certificates

WORKDIR /app

RUN chown nobody:nobody /app

COPY --from=builder --chown=nobody:nobody /app/_build/prod/rel/typster ./

USER nobody:nobody

ENV PHX_SERVER=true
ENV MIX_ENV=prod

EXPOSE 4000

CMD ["/app/bin/typster", "start"]
