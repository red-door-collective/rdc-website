{ sources ? null }:
let
  deps = import ./nix/deps.nix { inherit sources; };
  inherit (deps) pkgs;

  kernels = [
    # pkgs.python37Packages.ansible-kernel
    # pythonPackages.jupyter-c-kernel
    # pkgs.gophernotes
  ];

  additionalExtensions = [
    # "@jupyterlab/toc"
    # "@jupyterlab/fasta-extension"
    # "@jupyterlab/geojson-extension"
    # "@jupyterlab/katex-extension"
    # "@jupyterlab/mathjax3-extension"
    # "@jupyterlab/plotly-extension"
    # "@jupyterlab/vega2-extension"
    # "@jupyterlab/vega3-extension"
    # "@jupyterlab/xkcd-extension"
    # "jupyterlab-drawio"
    # "@jupyterlab/hub-extension"
    #jupyter labextension install @jupyter-widgets/jupyterlab-manager
    #jupyter labextension install @bokeh/jupyter_bokeh
    "@jupyter-widgets/jupyterlab-manager"
    "@bokeh/jupyter_bokeh"
    "@pyviz/jupyterlab_pyviz"
    # "jupyterlab_bokeh"
  ];

in pkgs.mkShell rec {
  buildInputs = deps.shellInputs ++ [
    pkgs.nodejs
  ] ++ kernels;
 
  shellHook = ''
    export TEMPDIR=$(mktemp -d -p /tmp)
    mkdir -p $TEMPDIR
    cp -r ${pkgs.python37Packages.jupyterlab}/share/jupyter/lab/* $TEMPDIR
    chmod -R 755 $TEMPDIR
    echo "$TEMPDIR is the app directory"

    # kernels
    export JUPYTER_PATH="${pkgs.lib.concatMapStringsSep ":" (p: "${p}/share/jupyter/") kernels}"

# labextensions
${pkgs.stdenv.lib.concatMapStrings
     (s: "jupyter labextension install --no-build --app-dir=$TEMPDIR ${s}; ")
     (pkgs.lib.unique
       ((pkgs.lib.concatMap
           (d: pkgs.lib.attrByPath ["passthru" "jupyterlabExtensions"] [] d)
           buildInputs) ++ additionalExtensions))  }
jupyter lab build --app-dir=$TEMPDIR
chmod -R +w $TEMPDIR/staging/
jupyter lab build --app-dir=$TEMPDIR
jupyter lab --app-dir=$TEMPDIR
    '';
}
