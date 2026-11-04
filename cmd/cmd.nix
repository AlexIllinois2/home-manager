{ config, pkgs, ... }: {
  imports = [
    ./zsh.nix
    ./vim.nix
  ];
}
