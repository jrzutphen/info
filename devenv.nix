{ pkgs, ... }:

{
  packages = with pkgs; [
    (python3.withPackages (
      ps: with ps; [ mkdocs-material ]
      ++ mkdocs-material.optional-dependencies.recommended
      ++ mkdocs-material.optional-dependencies.git
      ++ mkdocs-material.optional-dependencies.imaging
    ))
  ];
}
