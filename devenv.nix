{ pkgs, config, ... }:
{
  languages.gleam.enable = true;
  languages.gleam.package = pkgs.gleam;

  languages.erlang.enable = true;
  languages.erlang.package = pkgs.beamPackages.erlang;
  languages.erlang.lsp.enable = false;

  packages = with pkgs; [
    lcov
    jq
    curl
    git
    nodejs_24
  ];

  # Keep the Gleam/Hex cache inside the project so the environment is
  # reproducible and works on machines with a read-only home cache.
  env.XDG_CACHE_HOME = "${config.devenv.root}/.cache";

  scripts.test.exec = "gleam test";
  scripts.coverage.exec = "gleam run -m glcov -- run";
  scripts.check.exec = "gleam format --check src test && gleam build --warnings-as-errors";

  enterShell = ''
    gleam --version
    erl -noshell -eval 'io:format("OTP ~s~n", [erlang:system_info(otp_release)]), halt().'
    lcov --version
  '';

  enterTest = ''
    gleam format --check src test
    gleam build --warnings-as-errors
    gleam test
  '';
}
