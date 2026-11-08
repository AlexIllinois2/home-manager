{ pkgs, lib, ... }:

let
  host = pkgs.stdenv.hostPlatform;
in
{
  # 网络工具。分两类：
  #   1) 纯用户态、所有平台可用：curl / wget / aria2 / fping / nmap
  #   2) 需要原始套接字（CAP_NET_RAW）、只有桌面给：arp-scan
  #
  # xplay6（aarch64-linux / Android / proot / 普通 app uid）实测结论：
  #   - curl/wget/aria2：可用（原有网络栈，纯 socket）。
  #   - fping 5.2：可用。探测是 ICMP datagram socket，设备允许（实测
  #     `fping -c 2 127.0.0.1` 2/2 收到）。
  #   - nmap 7.94：可用，但只能做非特权扫描（`-sT` 实测可扫通本机 2222）；
  #     `-sS` 明确报 "requires root privileges"，这是设计限制，不是装坏了。
  #   - arp-scan 1.10：不可用。它走 libpcap 的 AF_PACKET，普通 app uid 没有
  #     CAP_NET_RAW，实测 `pcap_activate: Operation not permitted`。
  #     proot 也无法提权，故设备侧不装；桌面 x86_64 保留。
  home.packages =
    (with pkgs; [
      curl
      wget
      aria2
      fping
      nmap
    ])
    ++ lib.optionals (host.isx86_64) [
      # 桌面/普通 NixOS 主机：有 root 能力时 arp-scan 才能用；
      # 普通用户仍可能被 pcap 权限挡住，属预期。
      pkgs.arp-scan
    ];
}
