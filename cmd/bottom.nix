{ pkgs, ... }:

{
  programs.bottom = {
    enable = true;
    settings = {
      flags = {
        default_time_value = "120s"; # 示例：设置默认时间窗口为 120 秒
      };
    };
  };
}
