{ config, pkgs, ... }: {
  imports = [
    ./zsh.nix
    ./vim.nix
    ./bottom.nix
  ];
}
