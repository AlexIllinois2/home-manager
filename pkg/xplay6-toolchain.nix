{
  pkgs,
  lib,
  ...
}:

{
  # xplay6（aarch64-linux / Android）的打包工具链。
  #
  # 只声明 24.05 + aarch64 上真实可用的包：
  #   - jdk17        : OpenJDK 17.0.7，AGP 8.x 要求
  #   - gradle       : 8.7（JVM 程序，架构无关）
  #   - apksigner    : 纯 Java，用于签名 APK
  #   - android-tools: AOSP adb/fastboot，aarch64 源码构建
  #   - cargo/rustc  : 1.77.2
  #   - nodejs       : 20.18.1
  #
  # 刻意不包含 androidenv 的 build-tools / platform-tools / cmdline-tools：
  # nixpkgs 24.05 的 androidenv 对 linux 固定取官方 x86_64 压缩包
  # （compose-android-packages.nix 里 os = "linux"），aarch64 上产物是
  # x86_64 ELF，无法在设备上执行。aapt2 同理（pkgs.aapt 也是下载
  # aapt2-8.0.2-linux.jar，仅 x86_64）。详见本次迁移报告。
  home.packages = with pkgs; [
    jdk17
    gradle
    apksigner
    android-tools
    # cargo/rustc 本身不带链接器，rustc 会调用 `cc`，必须显式提供。
    gcc
    cargo
    rustc
    nodejs
  ];
}
