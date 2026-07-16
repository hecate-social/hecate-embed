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
%% app is a pure library and starts no listener. The port is read from the
%% environment directly (HECATE_EMBED_PORT), so the release needs no
%% RELX_REPLACE_OS_VARS substitution (whose awk chokes on some base images),
%% falling back to the app-env `http_port'.
server_children() ->
    case service_port() of
        Port when is_integer(Port) -> [server_child(Port)];
        undefined                  -> []
    end.

service_port() ->
    port_from_env(os:getenv("HECATE_EMBED_PORT")).

port_from_env(false) -> app_port();
port_from_env("")    -> app_port();
port_from_env(S)     -> parse_port(S).

app_port() ->
    case application:get_env(hecate_embed, http_port) of
        {ok, P} when is_integer(P) -> P;
        _NotAnInt                  -> undefined
    end.

parse_port(S) ->
    case string:to_integer(S) of
        {P, _Rest} when is_integer(P) -> P;
        _NotAnInt                     -> undefined
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
