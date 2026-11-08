{ pkgs, ... }:

{
  # 基础通用工具：所有设备（桌面 v / xplay6）都需要。
  #
  # 补的是“系统层本来该有、但 Nix-on-Droid 的 proot 环境里没有”的那批：
  # 设备上新装 Nix-on-Droid 后连 sed/grep/find 都没有，只能靠 nix shell 临时补。
  # 这里统一按 nixpkgs 的 GNU 版本装齐，桌面同样受益（版本与行为一致）。
  #
  # 只放与平台无关、纯用户态、无特权要求的命令；
  # 网络工具见 net.nix，搜索/开发工具见 dev.nix，重量级见 heavy.nix。
  home.packages = with pkgs; [
    # GNU coreutils 已由 Nix 自身与 HM 依赖带入，但显式声明可以保证
    # 设备 profile 里一定有完整的一套（ls/cp/mv/ln/tr/sort/uniq/...）。
    coreutils
    gnused
    gawk
    gnugrep
    findutils
    diffutils

    # 查看/查找/格式化
    less
    which
    file
    tree
    jq
    yq-go # nixpkgs 里 yq 的 Go 实现，二进制名仍为 yq

    # 压缩包：zip/unzip + GNU tar + unar（unar 支持 rar/7z 等，闭包约 130M）
    zip
    unzip
    gnutar
    unar

    # 磁盘与同步
    ncdu # 交互式磁盘占用分析
    # rsync：xplay6 上 ssh 的 sftp 子系统不可用（sftp-server 在 proot 下
    # prctl 失败），日常同步/拷贝改用 rsync 走 exec 通道。
    rsync
  ];

  # ssh 不在这里声明：桌面由系统提供，xplay6 由 hosts/xplay6.nix 单独装
  # openssh（sshd 与客户端同一份）。
}
