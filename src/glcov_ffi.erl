-module(glcov_ffi).

-export([
    plain_args/0,
    is_erlang/0,
    halt/1,
    eprintln/1,
    get_cwd/0,
    set_cwd/1,
    find_project_root/0,
    read_file/1,
    file_exists/1,
    is_dir/1,
    write_file/2,
    which/1,
    ensure_app_started/1,
    run/3,
    capture/3,
    otp_release/0,
    add_code_paths/1,
    find_ebins/1,
    beam_sources/1,
    beam_functions/1,
    profile_tests/3,
    cover_start/0,
    cover_compile/1,
    cover_analyse/1,
    cover_stop/0,
    run_tests/2
]).

%%%-------------------------------------------------------------------
%%% Process / OS helpers
%%%-------------------------------------------------------------------

plain_args() ->
    [to_bin(Arg) || Arg <- init:get_plain_arguments()].

is_erlang() ->
    true.

halt(Code) when is_integer(Code) ->
    erlang:halt(Code).

eprintln(Message) ->
    io:put_chars(standard_error, [to_bin(Message), $\n]),
    nil.

get_cwd() ->
    {ok, Cwd} = file:get_cwd(),
    to_bin(Cwd).

set_cwd(Path) ->
    case file:set_cwd(to_list(Path)) of
        ok -> {ok, nil};
        {error, Reason} -> {error, fmt(Reason)}
    end.

find_project_root() ->
    {ok, Cwd} = file:get_cwd(),
    find_project_root(Cwd).

find_project_root(Dir) ->
    case filelib:is_regular(filename:join(Dir, "gleam.toml")) of
        true ->
            to_bin(Dir);
        false ->
            Parent = filename:dirname(Dir),
            case Parent =:= Dir of
                true -> <<>>;
                false -> find_project_root(Parent)
            end
    end.

read_file(Path) ->
    case file:read_file(to_list(Path)) of
        {ok, Binary} -> {ok, Binary};
        {error, Reason} -> {error, fmt(Reason)}
    end.

file_exists(Path) ->
    filelib:is_regular(to_list(Path)).

is_dir(Path) ->
    filelib:is_dir(to_list(Path)).

write_file(Path, Contents) ->
    File = to_list(Path),
    case filelib:ensure_dir(File) of
        ok ->
            case file:write_file(File, Contents) of
                ok -> {ok, nil};
                {error, Reason} -> {error, fmt(Reason)}
            end;
        {error, Reason} ->
            {error, fmt(Reason)}
    end.

which(Name) ->
    case os:find_executable(to_list(Name)) of
        false -> {error, <<"not found on PATH">>};
        Path -> {ok, to_bin(Path)}
    end.

ensure_app_started(AppName) ->
    App = binary_to_atom(to_bin(AppName), utf8),
    case application:ensure_all_started(App) of
        {ok, _Started} -> {ok, nil};
        {error, Reason} -> {error, fmt(Reason)}
    end.

%% Run a program, streaming its combined stdout/stderr to ours.
run(Program, Args, Cwd) ->
    Port = open_program(Program, Args, Cwd),
    wait_for_exit(Port).

capture(Program, Args, Cwd) ->
    Port = open_program(Program, Args, Cwd),
    capture_output(Port, []).

open_program(Program, Args, Cwd) ->
    open_port(
        {spawn_executable, to_list(Program)},
        [
            binary,
            exit_status,
            use_stdio,
            stderr_to_stdout,
            {args, [to_list(Arg) || Arg <- Args]},
            {cd, to_list(Cwd)}
        ]
    ).

wait_for_exit(Port) ->
    receive
        {Port, {data, Data}} ->
            io:put_chars(Data),
            wait_for_exit(Port);
        {Port, {exit_status, Status}} ->
            Status;
        {Port, closed} ->
            1;
        {'EXIT', Port, _Reason} ->
            2
    end.

capture_output(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            capture_output(Port, [Data | Acc]);
        {Port, {exit_status, Status}} ->
            {Status, iolist_to_binary(lists:reverse(Acc))};
        {Port, closed} ->
            {1, iolist_to_binary(lists:reverse(Acc))};
        {'EXIT', Port, _Reason} ->
            {2, iolist_to_binary(lists:reverse(Acc))}
    end.

otp_release() ->
    to_bin(erlang:system_info(otp_release)).

add_code_paths(Paths) ->
    lists:foreach(
        fun(Path) ->
            _ = code:add_patha(to_list(Path)),
            ok
        end,
        Paths
    ),
    nil.

%%%-------------------------------------------------------------------
%%% Build artefacts and source mapping
%%%-------------------------------------------------------------------

find_ebins(Root) ->
    Pattern = filename:join([to_list(Root), "build", "dev", "erlang", "*", "ebin"]),
    Dirs = filelib:wildcard(Pattern),
    [to_bin(Dir) || Dir <- Dirs, filelib:is_dir(Dir)].

%% Returns [{ModuleName, SourcePath, BeamPath}]. SourcePath is empty when
%% the beam has no debug_info/abstract code.
beam_sources(Ebin) ->
    Beams = filelib:wildcard(filename:join(to_list(Ebin), "*.beam")),
    [beam_source(Beam) || Beam <- Beams].

beam_source(Beam) ->
    BeamPath = to_list(Beam),
    Module = list_to_atom(filename:basename(BeamPath, ".beam")),
    ModuleBin = atom_to_binary(Module, utf8),
    case beam_lib:chunks(BeamPath, [abstract_code]) of
        {ok, {Module, [{abstract_code, {raw_abstract_v1, Forms}}]}} ->
            {ModuleBin, source_path(Forms), to_bin(BeamPath)};
        {ok, {_, [{abstract_code, no_abstract_code}]}} ->
            {ModuleBin, <<>>, to_bin(BeamPath)};
        _ ->
            {ModuleBin, <<>>, to_bin(BeamPath)}
    end.


beam_functions(Beam) ->
    case beam_lib:chunks(to_list(Beam), [abstract_code]) of
        {ok, {_, [{abstract_code, {raw_abstract_v1, Forms}}]}} ->
            [
                {atom_to_binary(Name, utf8), Arity, annotation_line(Anno)}
             || {function, Anno, Name, Arity, _} <- Forms
            ];
        _ ->
            []
    end.

annotation_line(Anno) when is_integer(Anno) -> Anno;
annotation_line(Anno) -> erl_anno:line(Anno).

%% Returns {ok, TestStatus, TotalMeasurement, [{Module, Function, Arity,
%% Calls, Measurement, PercentBasisPoints}]} or {error, Message}.
profile_tests(Root, Color, ModeBin) ->
    case code:which(tprof) of
        non_existing ->
            {error, <<"profiling requires Erlang/OTP 27 or newer">>};
        _ ->
            Mode = binary_to_atom(to_bin(ModeBin), utf8),
            Modules = test_modules(to_list(Root)),
            case Modules of
                [] ->
                    {ok, {0, 0, []}};
                _ ->
                    try
                        Options = #{type => Mode, report => return, set_on_spawn => true},
                        Fun = fun() -> run_eunit(Modules, Color) end,
                        {TestResult, {Type, Raw}} = tprof:profile(Fun, Options),
                        #{all := {_Type, Total, Lines}} =
                            tprof:inspect({Type, Raw}, total, {measurement, descending}),
                        Rows = [
                            begin
                                PercentBp =
                                    case Total of
                                        0 -> 0;
                                        _ -> Measurement * 10000 div Total
                                    end,
                                {
                                    atom_to_binary(Module, utf8),
                                    atom_to_binary(Function, utf8),
                                    Arity,
                                    Calls,
                                    Measurement,
                                    PercentBp
                                }
                            end
                         || {Module, {Function, Arity}, Calls, Measurement, _PerCall, _Percent} <-
                                Lines
                        ],
                        {ok, {test_status(TestResult), Total, Rows}}
                    catch
                        Class:Reason:Stack ->
                            {error, fmt({Class, Reason, Stack})}
                    end
            end
    end.

test_status({ok, nil}) -> 0;
test_status(ok) -> 0;
test_status({error, _}) -> 1;
test_status(error) -> 1;
test_status(_) -> 1.

source_path(Forms) ->
    case find_file_attribute(Forms) of
        {ok, File} -> to_bin(File);
        error -> <<>>
    end.

find_file_attribute([{attribute, _Anno, file, {File, _Line}} | _]) ->
    {ok, File};
find_file_attribute([_ | Rest]) ->
    find_file_attribute(Rest);
find_file_attribute([]) ->
    error.

%%%-------------------------------------------------------------------
%%% Cover lifecycle
%%%-------------------------------------------------------------------

cover_start() ->
    try cover:start() of
        {ok, _Pid} -> {ok, nil};
        {error, {already_started, _Pid}} -> {ok, nil};
        {error, Reason} -> {error, fmt(Reason)};
        Other -> {error, fmt(Other)}
    catch
        Class:Reason -> {error, fmt({Class, Reason})}
    end.

%% Returns a list of {BeamPath, Reason} failures.
cover_compile(Beams) ->
    Failures = lists:foldl(
        fun(Beam, Acc) ->
            try cover:compile_beam(to_list(Beam)) of
                {ok, _Module} -> Acc;
                {error, Reason} -> [{to_bin(Beam), fmt(Reason)} | Acc];
                Other -> [{to_bin(Beam), fmt(Other)} | Acc]
            catch
                Class:Reason -> [{to_bin(Beam), fmt({Class, Reason})} | Acc]
            end
        end,
        [],
        Beams
    ),
    lists:reverse(Failures).

%% Returns {ok, [{Module, [{Line, Covered}]}]} or {error, Message}.
cover_analyse(Modules) ->
    Results = [analyse_module(Module) || Module <- Modules],
    case [Error || {error, Error} <- Results] of
        [] -> {ok, [Result || {ok, Result} <- Results]};
        [Error | _] -> {error, Error}
    end.

analyse_module(ModuleBin) ->
    Module = binary_to_atom(ModuleBin, utf8),
    try cover:analyse(Module, coverage, line) of
        {ok, Items} ->
            Lines = [
                {Line, Covered > 0}
                || {{Mod, Line}, {Covered, _NotCovered}} <- Items,
                   Mod =:= Module,
                   is_integer(Line)
            ],
            {ok, {ModuleBin, Lines}};
        {error, {not_cover_compiled, _}} ->
            {error, <<"module was not cover-compiled: ", ModuleBin/binary>>};
        Other ->
            {error, fmt(Other)}
    catch
        Class:Reason -> {error, fmt({Class, Reason})}
    end.

cover_stop() ->
    try cover:stop() of
        _ -> nil
    catch
        _:_ -> nil
    end.

%%%-------------------------------------------------------------------
%%% Test runner
%%%-------------------------------------------------------------------

run_tests(Root, Color) ->
    RootList = to_list(Root),
    Modules = test_modules(RootList),
    case Modules of
        [] ->
            io:format(standard_error, "glcov: no test modules found under test/~n", []),
            0;
        _ ->
            try run_eunit(Modules, Color) of
                {ok, nil} -> 0;
                ok -> 0;
                {error, _} -> 1;
                error -> 1;
                _ -> 1
            catch
                Class:Reason:Stack ->
                    io:format(
                        standard_error,
                        "glcov: test runner failed: ~p:~p~n~p~n",
                        [Class, Reason, Stack]
                    ),
                    2
            end
    end.

run_eunit(Modules, Color) ->
    case code:which(gleeunit_ffi) of
        non_existing ->
            eunit:test(Modules, [verbose, no_tty]);
        _ ->
            case code:which(gleeunit_progress) of
                non_existing ->
                    eunit:test(Modules, [verbose, no_tty]);
                _ ->
                    gleeunit_ffi:run_eunit(
                        Modules,
                        [
                            verbose,
                            no_tty,
                            {report, {gleeunit_progress, [{colored, Color}]}},
                            {scale_timeouts, 10}
                        ]
                    )
            end
    end.

test_modules(Root) ->
    TestDir = filename:join(Root, "test"),
    GleamFiles = filelib:wildcard("**/*.gleam", TestDir),
    ErlFiles = filelib:wildcard("**/*.erl", TestDir),
    Modules = lists:uniq([
        module_atom(File)
        || File <- GleamFiles ++ ErlFiles
    ]),
    %% Gleeunit passes every file in test/ to EUnit, but helper modules and
    %% vendored copies of gleeunit itself are not tests. Restrict the runner
    %% to modules that export an EUnit test function; this avoids loading
    %% vendored helper modules as tests (which can fail on their own FFI).
    [Module || Module <- Modules, exports_test_function(Module)].

exports_test_function(Module) ->
    case code:ensure_loaded(Module) of
        {module, Module} ->
            lists:any(
                fun({Name, _Arity}) -> is_test_function_name(atom_to_list(Name)) end,
                Module:module_info(exports)
            );
        _ ->
            false
    end.

is_test_function_name(Name) ->
    lists:suffix("_test", Name) orelse lists:suffix("_test_", Name).

module_atom(File) ->
    WithoutExtension =
        case filename:extension(File) of
            ".gleam" -> filename:rootname(File, ".gleam");
            ".erl" -> filename:rootname(File, ".erl");
            _ -> File
        end,
    Normalised = lists:flatten(string:replace(WithoutExtension, "\\", "/", all)),
    list_to_atom(lists:flatten(string:replace(Normalised, "/", "@", all))).

%%%-------------------------------------------------------------------
%%% Helpers
%%%-------------------------------------------------------------------

to_bin(Bin) when is_binary(Bin) -> Bin;
to_bin(List) when is_list(List) -> unicode:characters_to_binary(List);
to_bin(Atom) when is_atom(Atom) -> atom_to_binary(Atom, utf8).

to_list(Bin) when is_binary(Bin) -> unicode:characters_to_list(Bin);
to_list(List) when is_list(List) -> List;
to_list(Atom) when is_atom(Atom) -> atom_to_list(Atom).

fmt(Reason) when is_binary(Reason) -> Reason;
fmt(Reason) -> unicode:characters_to_binary(io_lib:format("~p", [Reason])).
