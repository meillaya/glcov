-module(fixture_stateful_app).
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    _ = fixture_stateful_marker:app_started(),
    {ok, self()}.

stop(_State) ->
    ok.
