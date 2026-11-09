{ config, lib, pkgs, ... }:

{
  # 共享 DNS 清单（dns.nix）。这里只做 nix-on-droid 系统层的落点，
  # home-manager 在桌面上不写 /etc/resolv.conf。
  imports = [ ../dns.nix ];

  # 登录 shell。nix-on-droid 的 user.shell（默认 bashInteractive）会被写进
  # /etc/passwd 的 shell 字段，并由 login-inner 以 `exec -a "-zsh"` 拉起，
  # 因此这里才是“打开应用进哪个 shell”的唯一开关。
  # home-manager 的 makeZshDefault 走 /usr/bin/chsh 与 /etc/shells，Android 上
  # 都没有，已在 hosts/begonia.nix 里禁用；它也不会影响 login-inner。
  # 取 24.05 的 pkgs.zsh：home-manager 用 useGlobalPkgs，programs.zsh 引用同一路径。
  user.shell = "${pkgs.zsh}/bin/zsh";

  # Nix-on-Droid 系统层只保留运行环境，CLI 软件全部交给 home-manager。
  # 默认模板里的 vim 会与 home-manager 的 vim 在 bin/ex 上冲突。
  environment.packages = [ ];

  environment.etcBackupExtension = ".bak";

  system.stateVersion = "24.05";

  nix.extraOptions = ''
    experimental-features = nix-command flakes
    sandbox = false

    # 国内镜像优先。默认只有 cache.nixos.org + nix-on-droid.cachix.org，
    # 在这台机器上拉大闭包会非常慢；镜像与官方签名一致，沿用官方
    # cache.nixos.org-1 与 nix-on-droid.cachix.org-1 公钥即可。
    # TUNA 的 /nix-channels/store 路径返回 "does not appear to be a binary cache"，
    # 因此不列入。
    substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://mirror.sjtu.edu.cn/nix-channels/store https://mirrors.cernet.edu.cn/nix-channels/store https://nix-on-droid.cachix.org https://cache.nixos.org
    trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-on-droid.cachix.org-1:56snoMJTXmDRC1Ei24CmKoUqvHJ9XCp+nidK7qkMQrU=
  '';

  # nix-on-droid 的 modules/environment/networking.nix 把 /etc/resolv.conf
  # 写死为 1.1.1.1 / 8.8.8.8。该网络下这两个地址不可用，这里用 mkForce
  # 覆盖为共享清单，切换 generation 后依然生效。
  environment.etc."resolv.conf".text = lib.mkForce config.my.dns.resolvConf;

  # 官方 home-manager 集成：系统层与 HM 共用同一套 24.05 pkgs。
  # home-manager-path 由 flake 的 home-manager-24_05 input 提供。
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.config = {
    imports = [
      ../home.nix
      ../hosts/begonia.nix
    ];

    # home.nix 里是桌面的 26.05，设备侧必须降到 24.05；
    # 两处都是普通定义，这里用 mkForce 覆盖。
    home.stateVersion = lib.mkForce "24.05";
  };
}
