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
    Children = [
        #{
            id       => hecate_embed_model_sup,
            start    => {hecate_embed_model_sup, start_link, []},
            restart  => permanent,
            shutdown => 5000,
            type     => supervisor,
            modules  => [hecate_embed_model_sup]
        }
    ],
    {ok, {SupFlags, Children}}.
