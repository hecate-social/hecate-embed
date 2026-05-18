# Getting started

`hecate_embed` computes sentence embeddings inside a running BEAM
node. The default model is multilingual (NL / FR / DE / IT / EN and
~100 others), produced by `intfloat/multilingual-e5-small`.

## Install

```erlang
%% rebar.config
{deps, [
    {hecate_embed, "~> 0.1"}
]}.
```

## Embed a single string

```erlang
{ok, M}   = hecate_embed:default_model().
{ok, Vec} = hecate_embed:embed(M, <<"de dossier reist langs balies"/utf8>>).
```

`Vec` is a list of `dim` floats. For the default model, `dim = 384`.

## Batch

```erlang
{ok, M}    = hecate_embed:default_model().
{ok, Vecs} = hecate_embed:embed_many(M, [
    <<"vertical slicing">>,
    <<"screaming architecture">>,
    <<"venture lifecycle">>
]).
```

Batched calls are recommended over one-at-a-time when you have more
than a handful of inputs; the NIF amortises tokeniser + ONNX setup
across the batch.

## Load a different model

```erlang
{ok, BigM} = hecate_embed:load_model(big, #{
    model_id => <<"intfloat/multilingual-e5-base">>,
    dim      => 768
}).
{ok, V}    = hecate_embed:embed(BigM, <<"text">>).
```

## Combining with hecate_vector

```erlang
{ok, M}   = hecate_embed:default_model().
{ok, Idx} = hecate_vector:open(my_corpus, #{dim => hecate_embed:dim(M)}).

{ok, V}   = hecate_embed:embed(M, <<"the dossier moves through desks">>),
ok        = hecate_vector:add(Idx, <<"chunk:001">>, V).

{ok, Q}    = hecate_embed:embed(M, <<"how do dossiers travel?">>),
{ok, Hits} = hecate_vector:search(Idx, Q, 5).
```
