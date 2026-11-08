{ config, pkgs, ... }: {
  imports = [
    ./zsh.nix
    ./vim.nix
    ./bottom.nix

    # 命令行环境按主题拆分，桌面与 xplay6 共用同一套：
    #   base.nix   基础通用（GNU 工具、查看、压缩、磁盘）
    #   dev.nix    开发/搜索（git/rg/fzf/fd/bat/eza/elfutils）
    #   net.nix    网络（curl/wget/aria2/fping/nmap，+ 桌面 arp-scan）
    #   heavy.nix  重量级开关位（llvm/qemu/gdb 等，默认关闭）
    ./base.nix
    ./dev.nix
    ./net.nix
    ./heavy.nix
  ];
}
