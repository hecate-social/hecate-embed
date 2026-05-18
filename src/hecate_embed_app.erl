%%% @doc hecate_embed OTP application entry point.
-module(hecate_embed_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    hecate_embed_sup:start_link().

stop(_State) ->
    ok.
