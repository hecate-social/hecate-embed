%%% @doc HTTP surface of the embedding service (an inets httpd `mod').
%%%
%%% Three routes, served when hecate_embed_server starts httpd:
%%%   POST /embed        #{text => binary()}    -> #{vector  => [float()]}
%%%   POST /embed_batch  #{texts => [binary()]} -> #{vectors => [[float()]]}
%%%   GET  /health                              -> #{status  => ok}
%%%
%%% The service is a DUMB embedder: it embeds raw text. Model-specific
%%% conventions (e5 query:/passage: prefixes) are applied by the caller's
%%% hecate_embed_model before the text is sent, so the service never needs to
%%% know whether a text is a query or a document.
-module(hecate_embed_http).

-export([do/1]).

-include_lib("inets/include/httpd.hrl").

do(#mod{method = "GET", request_uri = "/health"}) ->
    respond(200, encode(#{status => ok}));
do(#mod{method = "POST", request_uri = "/embed", entity_body = Body}) ->
    single(to_bin(Body));
do(#mod{method = "POST", request_uri = "/embed_batch", entity_body = Body}) ->
    batch(to_bin(Body));
do(#mod{}) ->
    respond(404, encode(#{error => <<"not found">>})).

single(Body) ->
    dispatch_single(field(<<"text">>, Body)).

dispatch_single(Text) when is_binary(Text) ->
    reply_embed(do_embed(Text), vector);
dispatch_single(_NotBinary) ->
    respond(400, encode(#{error => <<"expected {text: ...}">>})).

batch(Body) ->
    dispatch_batch(field(<<"texts">>, Body)).

dispatch_batch(Texts) when is_list(Texts) ->
    reply_embed(do_embed_many(Texts), vectors);
dispatch_batch(_NotList) ->
    respond(400, encode(#{error => <<"expected {texts: [...]}">>})).

do_embed(Text) ->
    {ok, Model} = hecate_embed:default_model(),
    hecate_embed:embed(Model, Text).

do_embed_many(Texts) ->
    {ok, Model} = hecate_embed:default_model(),
    hecate_embed:embed_many(Model, Texts).

reply_embed({ok, Result}, Key) ->
    respond(200, encode(#{Key => Result}));
reply_embed({error, Reason}, _Key) ->
    respond(500, encode(#{error => iolist_to_binary(io_lib:format("~p", [Reason]))})).

%% Decode the JSON body and pull one field; undefined if absent or malformed.
field(Key, Body) ->
    try json:decode(Body) of
        Map when is_map(Map) -> maps:get(Key, Map, undefined);
        _NotAnObject         -> undefined
    catch
        _Class:_Reason -> undefined
    end.

encode(Map) -> iolist_to_binary(json:encode(Map)).

to_bin(B) when is_binary(B) -> B;
to_bin(L) when is_list(L)   -> list_to_binary(L);
to_bin(_Other)             -> <<>>.

respond(Status, Body) ->
    Head = [{code, Status},
            {content_type, "application/json"},
            {content_length, integer_to_list(byte_size(Body))}],
    {proceed, [{response, {response, Head, Body}}]}.
