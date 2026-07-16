# hecate-embed — the shared per-node embedding SERVICE.
#
# One per node: the node's peers (e.g. the resident Spartan minds) reach it over
# loopback via the `remote' backend, so they do not each load the model. Debian/
# glibc, because fastembed's ONNX Runtime links against glibc; the model is baked
# in at build time so nothing is downloaded at runtime.
#
# Pushed to ghcr.io/hecate-social/hecate-embed:latest + :semver.

#----------------------------------------------------------------------
# Stage 1 — builder: Erlang + Rust + the real-embed NIF + the model + release
#----------------------------------------------------------------------
FROM docker.io/erlang:28 AS builder
WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl bash build-essential cmake \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

RUN curl -fsSL https://s3.amazonaws.com/rebar3/rebar3 -o /usr/local/bin/rebar3 \
    && chmod +x /usr/local/bin/rebar3

COPY . .
RUN rebar3 get-deps && rebar3 compile

# The genuine ONNX embedder NIF (glibc; ONNX Runtime is statically linked in).
RUN CARGO_FEATURES=real-embed bash scripts/build-nif.sh

# Bake the model into the image so runtime needs no network (sovereign: nothing
# leaves the box in production).
RUN bash scripts/prefetch-model.sh /models

# Production release (bundles ERTS, strips debug_info).
RUN rebar3 as prod release

#----------------------------------------------------------------------
# Stage 2 — runtime: slim Debian + the release + the baked model
#----------------------------------------------------------------------
FROM docker.io/debian:bookworm-slim
# ONNX Runtime is static in the .so. These are the libs it still needs
# dynamically (its hf-hub download client) plus what ERTS needs to run.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libssl3 zlib1g libbrotli1 libzstd1 libstdc++6 libncurses6 \
        ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /build/_build/prod/rel/hecate_embed ./
COPY --from=builder /models /models

ENV HOME=/app
ENV RELX_REPLACE_OS_VARS=true
ENV HECATE_EMBED_PORT=8477
ENV HECATE_EMBED_MODEL_DIR=/models

EXPOSE 8477
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8477/health || exit 1

CMD ["bin/hecate_embed", "foreground"]
