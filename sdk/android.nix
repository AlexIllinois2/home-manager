{ pkgs, lib, ... }:

let
  host = pkgs.stdenv.hostPlatform;

  # apksigner 是纯 Java（自带 JRE，架构无关），两个平台共用同一份。
  apksigner = pkgs.apksigner;

  # ============================================================
  # aarch64-linux（设备侧：xplay6 / Android / proot 内 Nix-on-Droid）
  # ============================================================
  #
  # 来源：Termux 官方仓库 https://packages.termux.dev/apt/termux-main/
  #   这些包由 Termux 用 AOSP build-tools 源码 + Android NDK r30 交叉编译，
  #   产物是 bionic ELF（interpreter /system/bin/linker64，Android 24+）。
  #   proot 内 /system/bin/linker64 可直接执行，因此这些二进制在设备上可用；
  #   但它们按 Termux prefix（/data/data/com.termux/files/usr/lib）链接，
  #   所以运行库必须一起带上，并用包装脚本设置 LD_LIBRARY_PATH。
  #
  # 版本：build-tools 16.0.0.4；`aapt2 version` 输出
  #   "Android Asset Packaging Tool (aapt) 2.20-android-16.0.0_r4"；
  #   `aapt version` 为 "v0.2-android-16.0.0_r4"。
  #
  # 校验：hash 取自仓库索引 dists/stable/main/binary-aarch64/Packages 的
  #   SHA256，由 fetchurl 在构建时强制校验（不信任网络内容）。
  #
  # 升级：Termux 仓库升版后，改 URL 里的版本号与对应 hash；
  #   可用
  #     curl -fsSL https://packages.termux.dev/apt/termux-main/dists/stable/main/binary-aarch64/Packages.gz | gzip -dc
  #   查 Version / Filename / SHA256，或 `nix store prefetch-file <url>` 取 hash。
  #
  # 为什么不用 nixpkgs 的 aapt/androidenv（实测结论）
  #   - pkgs.aapt 只有 aapt2（没有 aapt/zipalign），且下载
  #     aapt2-8.0.2-linux.jar 解出 x86-64 ELF，aarch64 上
  #     "cannot execute: required file not found"。
  #   - androidenv."build-tools" 下载 build-tools_r34-linux.zip（官方 linux
  #     包只有 x86_64），同样无法执行。
  #
  # 为什么不自建 AOSP aapt2：需完整 AOSP/Soong + protobuf/abseil/fmt/
  #   libpng/libexpat，多 GB 检出与长构建；Termux 的包就是同源代码的
  #   NDK 产物，直接复用。
  #
  # 依赖闭包（readelf 递归统计）共 53 个 .so，来自下面 9 个包；
  # 这里直接安装各包全部 *.so，避免升级后漏依赖。
  aarch64Debs = {
    aapt = pkgs.fetchurl {
      url = "https://packages.termux.dev/apt/termux-main/pool/main/a/aapt/aapt_16.0.0.4-4_aarch64.deb";
      hash = "sha256-STO74n6apsVm8xcBX0J3aJCyuQ+8KgUD22vlmn03qIk=";
    };
    aapt2 = pkgs.fetchurl {
      url = "https://packages.termux.dev/apt/termux-main/pool/main/a/aapt2/aapt2_16.0.0.4-4_aarch64.deb";
      hash = "sha256-Gz5NcWZw14/tSmbgShupKCejb+MADpvvmCCDkvMQAFA=";
    };
    abseil = pkgs.fetchurl {
      url = "https://packages.termux.dev/apt/termux-main/pool/main/a/abseil-cpp/abseil-cpp_20260817.0_aarch64.deb";
      hash = "sha256-tpiWO7cJZJStkozonNhppT5q3wsF9fQHtA/anIXG4rA=";
    };
    fmt = pkgs.fetchurl {
      url = "https://packages.termux.dev/apt/termux-main/pool/main/f/fmt/fmt_1:12.2.0_aarch64.deb";
      hash = "sha256-Siy0OrFnsy2vDXl48hxTkdF7zkfa5qoqizqPlY5mPOc=";
    };
    libcxx = pkgs.fetchurl {
      url = "https://packages.termux.dev/apt/termux-main/pool/main/libc/libc++/libc++_30_aarch64.deb";
      hash = "sha256-U9C4SnunRZAkJXy5TVsTb+E++FhWf2WoBks1lQeZ8so=";
    };
    libexpat = pkgs.fetchurl {
      url = "https://packages.termux.dev/apt/termux-main/pool/main/libe/libexpat/libexpat_2.10.0_aarch64.deb";
      hash = "sha256-DkQR8B9vtmTz8E+UICiUcvmvww2wHqHF0eV/2fojVL4=";
    };
    libpng = pkgs.fetchurl {
      url = "https://packages.termux.dev/apt/termux-main/pool/main/libp/libpng/libpng_1.6.59_aarch64.deb";
      hash = "sha256-MtYfCxpgz3KDqjqA4ohzdJPfLGuEyMdJYGt3yUoQ8rI=";
    };
    libprotobuf = pkgs.fetchurl {
      url = "https://packages.termux.dev/apt/termux-main/pool/main/libp/libprotobuf/libprotobuf_2:36.2-1_aarch64.deb";
      hash = "sha256-2qO5Fp4JRkS6lcNdQKXMKDRzFE3sx9roOWxJzFFECBU=";
    };
    zlib = pkgs.fetchurl {
      url = "https://packages.termux.dev/apt/termux-main/pool/main/z/zlib/zlib_1.4_aarch64.deb";
      hash = "sha256-4wJ1Za5QvNi6URPJiLWJdUrhksnMPmr74+TtfAayWY4=";
    };
  };

  aarch64BuildTools = pkgs.stdenvNoCC.mkDerivation {
    pname = "android-build-tools-aarch64";
    version = "16.0.0.4";
    srcs = builtins.attrValues aarch64Debs;
    nativeBuildInputs = [
      pkgs.libarchive
      pkgs.xz
      pkgs.makeWrapper
    ];
    dontUnpack = true;

    buildPhase = ''
      runHook preBuild
      mkdir -p work
      for d in $srcs; do
        b=$(basename "$d")
        mkdir -p "work/$b"
        bsdtar -xf "$d" -C "work/$b"
        bsdtar -xf "work/$b/data.tar.xz" -C "work/$b"
      done
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/lib

      for d in work/*; do
        for b in aapt aapt2 zipalign; do
          if [ -e "$d/data/data/com.termux/files/usr/bin/$b" ]; then
            cp -a "$d/data/data/com.termux/files/usr/bin/$b" "$out/bin/$b"
          fi
        done
        cp -a "$d"/data/data/com.termux/files/usr/lib/*.so* $out/lib/ 2>/dev/null || true
      done

      ln -s ${apksigner}/bin/apksigner "$out/bin/apksigner"
      runHook postInstall
    '';

    # 二进制按 Termux prefix 链接，真实的 .so 在 $out/lib，因此用 wrapper
    # 追加 LD_LIBRARY_PATH。ANDROID_DATA/ANDROID_ROOT 是 aapt(v1) 通过
    # libcutils 读属性时需要的，缺省会直接 fatal（"ANDROID_DATA not set"）；
    # aapt2/zipalign 只是告警，一起设上更干净。
    postFixup = ''
      for b in aapt aapt2 zipalign; do
        wrapProgram "$out/bin/$b" \
          --prefix LD_LIBRARY_PATH : "$out/lib" \
          --set-default ANDROID_DATA /data \
          --set-default ANDROID_ROOT /system
      done
    '';

    meta.description = "Android build-tools (aapt2/aapt/zipalign/apksigner) for aarch64 Android via Termux binaries";
  };

  # ============================================================
  # x86_64-linux（桌面 v / 普通 NixOS 主机）
  # ============================================================
  #
  # 来源：官方 build-tools r34.0.0 linux 包（dl.google.com，与 androidenv
  #   用的同一份压缩包），aapt/aapt2/zipalign 都是 x86_64 预编译件。
  #   版本：aapt2 2.19-10229193、aapt v0.2-10229193（与设备侧 16.0.0.4
  #   版本号不同，但 compile/link/zipalign/签名行为一致）。
  # 校验：hash 由 `nix store prefetch-file` 取得，fetchurl 构建时强制校验。
  #
  # 为什么不用 pkgs.aapt：它只提供 aapt2，没有 aapt 与 zipalign。
  # 为什么不用 androidenv."build-tools"：该包标记为 unfree
  #   （android-sdk-build-tools），需要全局 allowUnfree，不合适。
  #
  # 官方二进制按 FHS 链接（interpreter /lib64/ld-linux-x86-64.so.2、
  # NEEDED libc++.so），NixOS 上没有这些路径，所以用 patchelf 改写
  # interpreter 与 rpath，libc++.so 从压缩包的 lib64 一起带上。
  x86_64BuildTools = pkgs.stdenvNoCC.mkDerivation {
    pname = "android-build-tools-x86_64";
    version = "34.0.0";
    src = pkgs.fetchurl {
      url = "https://dl.google.com/android/repository/build-tools_r34-linux.zip";
      hash = "sha256-6FjEtgBp0EMQUbIl04RBOxZD4SibAKSCWu00fyW9UQ8=";
    };
    nativeBuildInputs = [
      pkgs.unzip
      pkgs.patchelf
    ];
    sourceRoot = "android-14";
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/lib
      cp aapt aapt2 zipalign "$out/bin/"
      cp lib64/libc++.so "$out/lib/"
      ln -s ${apksigner}/bin/apksigner "$out/bin/apksigner"
      runHook postInstall
    '';

    postFixup = ''
      for b in aapt aapt2 zipalign; do
        patchelf --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \
                 --set-rpath "$out/lib:${pkgs.glibc}/lib" "$out/bin/$b"
      done
    '';

    meta.description = "Android build-tools (aapt2/aapt/zipalign/apksigner) for x86_64 Linux";
  };

  tools =
    if host.isLinux && host.isAarch64 then
      aarch64BuildTools
    else if host.isLinux && host.isx86_64 then
      x86_64BuildTools
    else
      throw ''
        sdk/android.nix: 当前平台 ${host.system} 没有可用的 Android build-tools。
        已支持：aarch64-linux（Termux bionic 产物）、x86_64-linux（官方预编译）。
        其他平台请显式移除这个模块的 import，避免装到一个不能用的包。'';
in
{
  # 对外统一暴露 aapt2 / aapt / zipalign / apksigner 四个命令；
  # 平台差异（LD_LIBRARY_PATH、ANDROID_DATA/ANDROID_ROOT、patchelf）都在
  # 上面的包装里处理，调用方（含 AGP 的 android.aapt2FromMavenOverride）
  # 只需用 $out/bin/aapt2。
  home.packages = [ tools ];
}
