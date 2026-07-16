%%% @doc The embedding service: hecate_embed run as a shared HTTP embedder.
%%%
%%% Started only when `http_port' is configured (see hecate_embed_sup), so a
%%% pure-library consumer never opens a listener. In service mode this owns a
%%% standalone inets httpd instance and warms the model at boot, so peers on the
%%% same node reach one shared embedder over loopback instead of each loading its
%%% own copy of the model.
-module(hecate_embed_server).
-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, terminate/2]).

-spec start_link(inet:port_number()) -> {ok, pid()} | {error, term()}.
start_link(Port) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, Port, []).

init(Port) ->
    process_flag(trap_exit, true),
    {ok, _} = application:ensure_all_started(inets),
    {ok, Httpd} = inets:start(httpd, httpd_config(Port), stand_alone),
    _ = warm_model(),
    logger:info("[hecate_embed] embedding service listening on port ~b", [Port]),
    {ok, #{httpd => Httpd, port => Port}}.

httpd_config(Port) ->
    [{port, Port},
     {bind_address, any},
     {server_name, "hecate_embed"},
     {server_root, "/tmp"},
     {document_root, "/tmp"},
     {mime_types, [{"json", "application/json"}]},
     {modules, [hecate_embed_http]}].

%% Load the model up front so the first request does not pay the load cost.
%% Best-effort: a transient failure just defers loading to first use rather than
%% crash-looping the service.
warm_model() ->
    catch hecate_embed:default_model().

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State)        -> {noreply, State}.

terminate(_Reason, #{httpd := Httpd}) ->
    _ = catch inets:stop(stand_alone, Httpd),
    ok;
terminate(_Reason, _State) ->
    ok.
