{
  lib,
  stdenv,
  fetchFromGitHub,
  gleam,
  beamPackages,
  makeWrapper,
  git,
  src,
  version,
}:

let
  inherit (beamPackages) erlang;

  # The only runtime dependency of the CLI. Vendoring it as a path
  # dependency keeps the Nix build offline and avoids a Hex cache.
  gleamStdlib = fetchFromGitHub {
    owner = "gleam-lang";
    repo = "stdlib";
    rev = "v1.0.5";
    hash = "sha256-onOUf1lYTj+rQxPMSM8V8PXdJEyuBiEJsqc2Z/m+kw0=";
  };
in
stdenv.mkDerivation {
  pname = "glcov";
  inherit version src;

  nativeBuildInputs = [
    gleam
    erlang
    makeWrapper
  ];

  dontStrip = true;

  buildPhase = ''
    runHook preBuild

    mkdir -p work
    cp -r ${src}/src work/src
    cd work

    cat > gleam.toml <<EOF
    name = "glcov"
    version = "${version}"
    target = "erlang"

    [dependencies]
    gleam_stdlib = { path = "${gleamStdlib}" }
    EOF

    export HOME="$TMPDIR"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    mkdir -p "$XDG_CACHE_HOME"

    gleam build --target erlang
    escript ${./build_escript.escript} glcov.escript \
      build/dev/erlang/glcov/ebin \
      build/dev/erlang/gleam_stdlib/ebin

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/glcov"
    cp glcov.escript "$out/share/glcov/glcov.escript"

    makeWrapper ${erlang}/bin/escript "$out/bin/glcov" \
      --add-flags "$out/share/glcov/glcov.escript" \
      --prefix PATH : ${
        lib.makeBinPath [
          gleam
          erlang
          git
        ]
      }

    runHook postInstall
  '';

  meta = with lib; {
    description = "Line coverage and profiling for Gleam projects on the Erlang target";
    license = licenses.asl20;
    mainProgram = "glcov";
    platforms = platforms.unix;
  };
}
