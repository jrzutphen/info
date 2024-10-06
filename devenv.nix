{ pkgs, ... }:

{
  packages = with pkgs; [
    (python3.withPackages (
      ps: with ps; [ mkdocs-material-insiders ]
      ++ mkdocs-material-insiders.optional-dependencies.recommended
      ++ mkdocs-material-insiders.optional-dependencies.git
      ++ mkdocs-material-insiders.optional-dependencies.imaging
    ))
  ];
}
