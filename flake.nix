{
  description = "Home Manager configuration of v";

  inputs = {
    # 桌面 v 继续使用 unstable
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # xplay6 专用的 24.05 通道（与设备上 Nix-on-Droid 24.05 对齐）
    nixpkgs-24_05.url = "github:nixos/nixpkgs/nixos-24.05";
    home-manager-24_05 = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs-24_05";
    };
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs-24_05";
      inputs.home-manager.follows = "home-manager-24_05";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nixpkgs-24_05,
      home-manager-24_05,
      nix-on-droid,
      ...
    }:
    let
      mkHome = system: modules: home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        inherit modules;
      };
    in
    {
      homeConfigurations."v" = mkHome "x86_64-linux" [
        ./home.nix
        ./gui/gui.nix
      ];

      # 无 GUI 变体：Nix-on-Droid (aarch64-linux / Android)，只装 CLI 部分
      homeConfigurations."xplay6" = mkHome "aarch64-linux" [
        ./home.nix
        ./hosts/xplay6.nix
      ];

      # Redmi Note 8 Pro：命令行先行版本，不含 sshd/自启（访问走 Termux 8022）。
      homeConfigurations."begonia" = mkHome "aarch64-linux" [
        ./home.nix
        ./hosts/begonia.nix
      ];

      # 官方 home-manager 集成：系统层与 HM 共用 24.05 的 pkgs
      nixOnDroidConfigurations.xplay6 = nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = import nixpkgs-24_05 { system = "aarch64-linux"; };
        modules = [ ./hosts/xplay6-nix-on-droid.nix ];
        home-manager-path = home-manager-24_05.outPath;
      };

      nixOnDroidConfigurations.begonia = nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = import nixpkgs-24_05 { system = "aarch64-linux"; };
        modules = [ ./hosts/begonia-nix-on-droid.nix ];
        home-manager-path = home-manager-24_05.outPath;
      };
    };
}
