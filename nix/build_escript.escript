#!/usr/bin/env escript

%% Build a self-contained glcov escript from compiled Gleam ebins.
%%
%% Usage: escript nix/build_escript.escript OUTPUT EBIN [EBIN ...]

main([Output | EbinDirs]) ->
    Files = lists:append([beam_files(Dir) || Dir <- EbinDirs]),
    ok = escript:create(
        Output,
        [
            shebang,
            {emu_args, "-escript main glcov_escript"},
            {archive, Files, []}
        ]
    ),
    io:format("wrote ~ts~n", [Output]);
main(_) ->
    io:format(standard_error, "usage: build_escript.escript OUTPUT EBIN...~n", []),
    halt(2).

beam_files(Dir) ->
    [
        begin
            {ok, Binary} = file:read_file(Path),
            {filename:basename(Path), Binary}
        end
     || Path <- filelib:wildcard(filename:join(Dir, "*.beam"))
    ].
