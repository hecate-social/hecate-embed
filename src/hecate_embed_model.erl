%%% @doc gen_server holding one loaded embedding model.
%%%
%%% Owns the NIF resource (an ONNX session). Mediates inference calls;
%%% the NIF itself is dirty-scheduler-safe for batches.
-module(hecate_embed_model).
-behaviour(gen_server).

-export([
    start_link/2,
    stop/1,
    embed/2,
    embed_many/2,
    dim/1,
    model_id/1
]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    name      :: atom(),
    model_id  :: binary(),
    dim       :: pos_integer(),
    handle    :: reference()
}).

start_link(Name, Opts) when is_atom(Name), is_map(Opts) ->
    gen_server:start_link({local, Name}, ?MODULE, {Name, Opts}, []).

stop(Ref) -> gen_server:stop(Ref).

embed(Ref, Text) -> gen_server:call(Ref, {embed, Text}).
embed_many(Ref, Texts) -> gen_server:call(Ref, {embed_many, Texts}, 60_000).
dim(Ref) -> gen_server:call(Ref, dim).
model_id(Ref) -> gen_server:call(Ref, model_id).

init({Name, Opts}) ->
    ModelId = maps:get(model_id, Opts, default_model_id()),
    Dim     = maps:get(dim,      Opts, default_dim()),
    ModelDir = maps:get(model_dir, Opts, default_model_dir()),
    case hecate_embed_nif:load(ModelId, Dim, to_charlist(ModelDir)) of
        {ok, Handle} ->
            {ok, #state{name = Name, model_id = ModelId, dim = Dim, handle = Handle}};
        {error, Reason} ->
            {stop, {load_failed, Reason}}
    end.

handle_call({embed, Text}, _From, #state{handle = H} = S) ->
    {reply, hecate_embed_nif:embed(H, Text), S};
handle_call({embed_many, Texts}, _From, #state{handle = H} = S) ->
    {reply, hecate_embed_nif:embed_many(H, Texts), S};
handle_call(dim, _From, #state{dim = D} = S) ->
    {reply, D, S};
handle_call(model_id, _From, #state{model_id = M} = S) ->
    {reply, M, S};
handle_call(_Other, _From, S) ->
    {reply, {error, unknown_call}, S}.

handle_cast(_, S) -> {noreply, S}.
handle_info(_, S) -> {noreply, S}.
terminate(_, _) -> ok.

%%% Internals

default_model_id() ->
    application:get_env(hecate_embed, default_model_id, <<"intfloat/multilingual-e5-small">>).

default_dim() ->
    application:get_env(hecate_embed, default_dim, 384).

default_model_dir() ->
    application:get_env(hecate_embed, model_dir, "priv/models").

to_charlist(B) when is_binary(B) -> binary_to_list(B);
to_charlist(L) when is_list(L)   -> L.
