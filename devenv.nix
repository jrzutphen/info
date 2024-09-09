{ pkgs, ... }:

{
  dotenv.enable = true;

  languages = {
    python = {
      enable = true;
      poetry = {
        enable = true;
        activate.enable = true;
        install.enable = true;
      };
    };
  };
}
