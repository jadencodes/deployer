# syntax=docker/dockerfile:experimental
FROM elixir:1.10.0-alpine as builder
ENV MIX_ENV prod

RUN mix local.hex --force && mix local.rebar --force

RUN mkdir /build
WORKDIR /build

COPY mix.exs /build
COPY mix.lock /build

RUN mix deps.get && mix deps.compile --include-children

COPY lib/ /build/lib

RUN mix release

FROM elixir:1.10.0-alpine

RUN mkdir /app
WORKDIR /app

COPY --from=builder "/build/_build/prod/rel/sample_webapp" /app
RUN rm -rf /build
EXPOSE 80

CMD ["/app/bin/sample_webapp", "start"]