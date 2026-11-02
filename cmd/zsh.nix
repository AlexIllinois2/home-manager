{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true; # 启用 Zsh

    # 历史记录设置
    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      path = "${config.home.homeDirectory}/.zsh_history";
    };

    enableCompletion = true; # 启用命令补全
    autosuggestion.enable = true; # 启用历史命令自动建议
    syntaxHighlighting.enable = true; # 启用语法高亮

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    initContent = ''
      source $HOME/.local/shell/zsh.zsh
      find $HOME/.local/shell/env -mindepth 1 2>/dev/null | while read -r line; do source "$line"; done
      find $HOME/.local/shell/rc -mindepth 1 2>/dev/null | while read -r line; do source "$line"; done
      unset line
    '';

    # 你的命令别名
    shellAliases = {
      ll = "ls -l";
      update = "sudo dnf upgrade"; # 在 Fedora 上更新系统
    };
  };
  
  # 自动化：在激活时尝试将 zsh 设为默认 shell
  home.activation.makeZshDefault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ZSH_PATH="${config.programs.zsh.package}/bin/zsh"
    if ! grep -q "$ZSH_PATH" /etc/shells 2>/dev/null; then
      echo "正在将 $ZSH_PATH 添加到 /etc/shells (需要 sudo 权限)"
      echo "$ZSH_PATH" | /usr/bin/sudo tee -a /etc/shells
    fi
    if [ "$SHELL" != "$ZSH_PATH" ]; then
      echo "正在切换默认 shell 为 zsh"
      /usr/bin/chsh -s "$ZSH_PATH"
    fi
  '';
}
