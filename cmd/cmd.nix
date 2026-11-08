{ config, pkgs, ... }: {
  imports = [
    ./zsh.nix
    ./vim.nix
    ./bottom.nix
  ];

  # 所有设备共享的命令行工具。
  # rsync：xplay6 上 ssh 的 sftp 子系统不可用（sftp-server 在 proot 下
  # prctl 失败），日常同步/拷贝改用 rsync 走 exec 通道。
  home.packages = with pkgs; [
    rsync
  ];
}
