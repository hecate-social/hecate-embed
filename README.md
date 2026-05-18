# hecate-embed

Local, multilingual sentence embedder for the Hecate ecosystem.

A thin Erlang/OTP wrapper around a Rust embedder (planned:
[`fastembed-rs`](https://github.com/Anush008/fastembed-rs) running ONNX
models locally; a deterministic hash-based stub in this scaffold)
exposed via Rustler NIFs. No OpenAI dependency, no outbound calls
unless you load a remote model.

## Status

**Scaffold.** API surface exists, NIF returns deterministically-shaped
fake vectors so the rest of the stack can integrate. Swap in
`fastembed-rs` + a real ONNX model before relying on quality.

## Why

- Sovereign stack: pure-Rust embedder, ONNX runtime, no Big Tech in the data path
- Multilingual default (NL / FR / DE / IT / EN) — matches the
  "Europe, not US" anchor
- BEAM-native: Rustler NIF, no sidecar, no IPC tax
- Pairs with [`hecate-vector`](https://codeberg.org/hecate-social/hecate-vector)
  for end-to-end RAG inside the Hecate daemon

## Public API

```erlang
{ok, Model} = hecate_embed:load_model(default, #{}).
{ok, Vec}   = hecate_embed:embed(Model, <<"the dossier moves through desks">>).
{ok, Vecs}  = hecate_embed:embed_many(Model, [<<"text1">>, <<"text2">>]).
Dim         = hecate_embed:dim(Model).  %% 384 by default
```

Vectors are lists of floats, length = `dim/1`. `embed/2` is safe to
call concurrently per `Model`.

## Default model

`multilingual-e5-small` (intfloat) — 384-dim, ~100M params, ONNX format,
Apache-2.0 weights. Handles 100+ languages, including all 4 official
languages of Belgium.

Override via `load_model/2`:

```erlang
{ok, M} = hecate_embed:load_model(big, #{
    model_id => <<"intfloat/multilingual-e5-base">>,
    dim      => 768
}).
```

## Architecture

```
hecate_embed              ← public facade
  └── hecate_embed_model  ← gen_server per loaded model
        └── hecate_embed_nif ← Rustler NIF
              └── native/hecate_embed_nif/  ← Rust crate (fastembed-rs / scaffold)
```

## Build

```bash
rebar3 compile           # also builds the Rust NIF via rebar3_cargo
rebar3 ct                # runs Common Test suites
scripts/fetch-model.sh   # downloads default model into priv/models/
```

## Status table

| Capability | Scaffold | Production |
|------------|----------|------------|
| `load_model/2` | ✅ | ✅ |
| `embed/2`, `embed_many/2` (deterministic stub) | ✅ | — |
| `embed/2` (real ONNX inference) | — | ⏳ wire fastembed-rs |
| Multilingual model | — | ⏳ |
| Quantised models (int8, fp16) | — | ⏳ |

## License

Apache-2.0. See [LICENSE](LICENSE).
