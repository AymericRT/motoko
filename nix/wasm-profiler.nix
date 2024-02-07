pkgs:
let
  subpath = import ./gitSource.nix;
  wasm-profiler-src = subpath ../wasm-profiler;
in {
  wasm-profiler-instrument =
    pkgs.rustPlatform.buildRustPackage {
      name = "wasm-profiler-instrument";

      src = wasm-profiler-src;

      # update this after dependency changes
      cargoSha256 = "sha256-kMKfMf2DyGVmWeoC6E/5vGDj3Bt3g2bEv1X/htFZ6pg=";
    };

  wasm-profiler-postproc = pkgs.stdenv.mkDerivation rec {
    name = "wasm-profiler-postproc";

    src = wasm-profiler-src;

    buildInputs = [ pkgs.perl ];

    installPhase = ''
      mkdir -p $out/bin
      cp $src/wasm-profiler-postproc.pl $out/bin/wasm-profiler-postproc
    '';
  };

  # the FlameGraph package is a bit inconvenient, with stuff like files.pl in
  # the path. Package a smaller, nicer one, with just the flamegraph tool.
  flamegraph-bin = pkgs.runCommandNoCC "flamegraph" {} ''
    mkdir -p $out/bin
    cp ${pkgs.flamegraph}/bin/flamegraph.pl $out/bin/flamegraph
  '';
}
