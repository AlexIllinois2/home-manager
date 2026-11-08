{ config, lib, ... }:

{
  # 所有设备共用的 DNS 地址清单。
  #
  # 这里只声明数据/选项，不产生任何 home.file 或 environment.etc 配置：
  # home-manager 在 x86_64 桌面上无法管理 /etc/resolv.conf，真正的落点
  # 只在 nix-on-droid 系统层（hosts/*-nix-on-droid.nix）里应用。
  options.my.dns = {
    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "119.29.29.29"
        "182.254.116.116"
        "114.114.114.114"
      ];
      description = "各设备共用的 DNS 地址清单（腾讯公共 DNS 两个 + 114）。";
    };

    resolvConf = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = lib.concatMapStrings (ns: "nameserver ${ns}\n") config.my.dns.nameservers;
      description = "由 nameservers 生成的 resolv.conf 文本，仅供 nix-on-droid 系统层使用。";
    };
  };
}
