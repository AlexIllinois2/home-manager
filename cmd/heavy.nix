{ ... }:

{
  # 重量级工具组：默认全部关闭，只作为“日后要装时改这里”的开关位。
  #
  # 体积参考（aarch64-linux 24.05，闭包解压后，含共享依赖）：
  #   llvm    641M
  #   qemu    1.6G（272 个路径）
  #   gdb     295M
  #   distrobox ~（未测，但依赖 systemd/podman，见下）
  #
  # 为什么默认不装：
  #   - llvm/qemu/gdb 不是日常必需，闭包明显偏大，xplay6 只有 66G 可用，
  #     不值得常驻。需要时把对应行取消注释即可。
  #   - distrobox：依赖 systemd 与容器运行时，Nix-on-Droid 的 proot 环境
  #     没有 systemd/pid 1，无法成立。
  #   - perf：24.05 的 attr 是 linuxPackages.perf，绑定特定内核版本；
  #     Android 上的内核不是 nixpkgs 那套，perf 事件接口不匹配。
  #   - bpftrace：依赖内核 BTF 与 perf_event_open，设备内核未开放，
  #     且 proot 下无 CAP_SYS_ADMIN。
  #   - gdb：需要 ptrace；Android app 进程对同 uid 子进程可用，但跨进程与
  #     断点场景受限，且 295M 体积对设备不划算。
  #
  # 桌面需要时，建议在这里按平台分支打开，例如：
  #   home.packages = lib.optionals (!host.isAarch64) (with pkgs; [ llvm gdb ]);
  home.packages = [ ];
}
