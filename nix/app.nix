# Build the actual Python application using poetry2nix.
{ mkPoetryApplication
, pyProject
, python
, ...
}:

mkPoetryApplication {
  projectDir = ./..;
  inherit python;

  passthru = {
    inherit (pyProject) version;
  };
}
