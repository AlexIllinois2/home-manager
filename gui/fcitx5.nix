{ config, pkgs, lib, ... }:

let
  fcitx5-rime-with-ice = pkgs.fcitx5-rime.override {
    rimeDataPkgs = [ pkgs.rime-ice ]; # 或使用 NUR 的 rime-ice
  };
in
{
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;

    fcitx5.addons = with pkgs; [
      fcitx5-rime-with-ice 
      rime-data
      fcitx5-gtk
      fcitx5-chinese-addons
      qt6Packages.fcitx5-configtool
    ];
  };

  # 可选：手动设置环境变量（NixOS 通常会自动处理，但某些情况下需要）
  environment.sessionVariables = {
    GTK_IM_MODULE=fcitx5;
    QT_IM_MODULE=fcitx5;
    XMODIFIERS="@im=fcitx5";
    INPUT_METHOD=fcitx5;
    SDL_IM_MODULE=fcitx5;
  };
}