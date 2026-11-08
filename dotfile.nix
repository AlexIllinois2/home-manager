{ config, lib, ... }:

let
  dotfilesDir = "${config.home.homeDirectory}/.config/home-manager/home";
  dotfilesPath = ./home;

  listFiles = exclude: dir: prefix:
    let
      entries = builtins.readDir dir;
    in
      lib.concatMap (name:
        let
          type = entries.${name};
          path = dir + "/${name}";
          rel  = if prefix == "" then name else "${prefix}/${name}";
        in
          if builtins.elem name exclude then [ ]
          else if type == "directory" then listFiles exclude path rel
          else if type == "regular"   then [ rel ]
          else [ ]
      ) (builtins.attrNames entries);

  relPaths = listFiles ([ ".git" "README.md" ] ++ config.dotfiles.exclude) dotfilesPath "";

  mkEntry = rel: {
    name  = rel;
    value.source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${rel}";
  };
in
{
  options.dotfiles.exclude = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "额外排除的 dotfile 名称（headless 设备用来去掉 GUI 相关片段）";
  };

  config.home.file = builtins.listToAttrs (map mkEntry relPaths);
}
