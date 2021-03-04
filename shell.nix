let
  pkgs = import ./nix/pkgs.nix;
  python = import ./nix/python.nix;
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

  frontendEnv = [
    pkgs.elmPackages.elm
    pkgs.elmPackages.elm-format
    pkgs.elmPackages.elm-live
    pkgs.elmPackages.elm-test
  ];

in pkgs.mkShell rec {
  EVICTION_TRACKER_SECRET_KEY = "development";
  ENVIRONMENT = "development";
  HOST = "127.0.0.1";
  PORT = "8080";

  buildInputs = [
    python.env
    pkgs.nodejs
    frontendEnv
  ] ++ kernels;
}
