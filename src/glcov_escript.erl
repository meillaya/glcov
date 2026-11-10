-module(glcov_escript).

-export([main/1]).

%% Entry point for the standalone escript.
%%
%% The escript bundles a copy of gleam_stdlib for its own CLI code, but the
%% project under test may use a different stdlib version. Add the project's
%% build paths before loading the CLI so the project's own stdlib wins. If the
%% project has not been built yet, build it first with a tiny Erlang-only
%% bootstrap; no Gleam stdlib modules are loaded until the paths are in place.
main(Arguments) ->
    BinArguments = [unicode:characters_to_binary(Argument) || Argument <- Arguments],
    case wants_help_or_version(BinArguments) of
        true ->
            glcov@cli:main_escript(BinArguments);
        false ->
            bootstrap(BinArguments)
    end.

bootstrap(Arguments) ->
    Root = project_root(Arguments),
    case Root of
        <<>> ->
            glcov@cli:main_escript(Arguments);
        _ ->
            NoBuild = lists:member(<<"--no-build">>, Arguments),
            case {NoBuild, glcov_ffi:find_ebins(Root)} of
                {false, []} ->
                    case build(Root) of
                        ok -> add_paths_and_run(Root, Arguments);
                        error -> halt(2)
                    end;
                _ ->
                    add_paths_and_run(Root, Arguments)
            end
    end.

add_paths_and_run(Root, Arguments) ->
    Ebins = glcov_ffi:find_ebins(Root),
    _ = glcov_ffi:add_code_paths(Ebins),
    glcov@cli:main_escript(Arguments).

build(Root) ->
    case glcov_ffi:which(<<"gleam">>) of
        {ok, Gleam} ->
            case glcov_ffi:run(Gleam, [<<"build">>, <<"--target">>, <<"erlang">>], Root) of
                0 -> ok;
                _Status ->
                    io:put_chars(standard_error, <<"glcov: `gleam build --target erlang` failed.\n">>),
                    error
            end;
        {error, Reason} ->
            io:format(standard_error, "glcov: could not find gleam: ~ts~n", [Reason]),
            error
    end.

project_root(Arguments) ->
    Wanted = case lists:splitwith(fun(Argument) -> Argument =/= <<"--root">> end, Arguments) of
        {_, [<<"--root">>, Root | _]} -> filename:absname(binary_to_list(Root));
        _ -> undefined
    end,
    case Wanted of
        undefined ->
            case glcov_ffi:find_project_root() of
                <<>> -> <<>>;
                Found -> Found
            end;
        WantedRoot ->
            list_to_binary(WantedRoot)
    end.

wants_help_or_version(Arguments) ->
    lists:any(
        fun(Argument) ->
            lists:member(Argument, [<<"--help">>, <<"-h">>, <<"--version">>, <<"-V">>])
        end,
        Arguments
    ).
