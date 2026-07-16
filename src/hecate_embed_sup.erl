%%% @doc Top-level supervisor for hecate_embed.
-module(hecate_embed_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy  => one_for_one,
        intensity => 10,
        period    => 10
    },
    Children = [model_sup_child() | server_children()],
    {ok, {SupFlags, Children}}.

model_sup_child() ->
    #{
        id       => hecate_embed_model_sup,
        start    => {hecate_embed_model_sup, start_link, []},
        restart  => permanent,
        shutdown => 5000,
        type     => supervisor,
        modules  => [hecate_embed_model_sup]
    }.

%% The HTTP embedding service runs only when a port is configured; otherwise the
%% app is a pure library and starts no listener.
server_children() ->
    case application:get_env(hecate_embed, http_port) of
        {ok, Port} when is_integer(Port) -> [server_child(Port)];
        _NotConfigured                   -> []
    end.

server_child(Port) ->
    #{
        id       => hecate_embed_server,
        start    => {hecate_embed_server, start_link, [Port]},
        restart  => permanent,
        shutdown => 5000,
        type     => worker,
        modules  => [hecate_embed_server]
    }.
