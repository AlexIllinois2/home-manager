{ config, pkgs, lib, ... }: {
  programs.vim = {
    enable = true;
    defaultEditor = true;        # 自动把 EDITOR 设成 vim

    settings = {
      number = true;
      relativenumber = true;
      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      ignorecase = true;
      smartcase = true;
    };

    # 裸 vimscript 写这里
    extraConfig = ''
      syntax on
      set mouse=a
      nnoremap <leader>w :w<CR>
    '';

    plugins = with pkgs.vimPlugins; [
      vim-airline
      vim-nix
      nerdtree
    ];
  };
}

