{
  pkgs,
  lib,
  ...
}:
let
  homeDir = "/data/data/com.termux.nix/files/home";
  sshPort = 2222;
in
{
  # Redmi Note 8 Pro（begonia）的 home-manager 设备差异。
  #
  # 定位：深入配置 nix 的命令行先行版本，逐步取代 Termux 成为手机端主要命令行
  # 环境。sshd 是可用的，但**不做任何自启**：
  #   - 不生成 ~/rc，不改 .bash_profile/.bashrc 去拉 sshd；
  #   - 需要 ssh 时手动执行 scripts/android/sshd-app.sh（或打开应用终端后手动跑）；
  #   - 没有任何 activation 依赖 root/su，也没有开机钩子。
  # 日常访问仍可走 Termux 的 sshd（8022）+ `su 10420`。

  # Nix-on-Droid 的固定布局：proot 内 HOME 为
  # /data/data/com.termux.nix/files/home（与包名绑定，和 xplay6 相同）。
  home.username = lib.mkForce "nix-on-droid";
  home.homeDirectory = lib.mkForce homeDir;

  # Android 上没有 /usr/bin/sudo、/usr/bin/chsh 与 /etc/shells，
  # zsh.nix 中的默认 shell 切换一定会失败，这里直接禁用该 activation。
  home.activation.makeZshDefault = lib.mkForce (lib.hm.dag.entryAfter [ "writeBoundary" ] "");

  # 设备上没有桌面环境与输入法，不加载相关 shell 片段。
  dotfiles.exclude = [
    "fcitx5.sh"
    "gnome.sh"
  ];

  # sshd 本体。host key 不在 store 里，放在持久 home 目录，
  # 由 scripts/android/sshd-app.sh 在首次启动时生成。
  home.packages = with pkgs; [ openssh ];

  home.file.".ssh/sshd_config".text = ''
    Port ${toString sshPort}
    AddressFamily inet
    ListenAddress 0.0.0.0

    HostKey ${homeDir}/.ssh/ssh_host_ed25519_key
    PidFile ${homeDir}/.ssh/sshd.pid

    PermitRootLogin no
    PubkeyAuthentication yes
    PasswordAuthentication no
    KbdInteractiveAuthentication no

    AuthorizedKeysFile .ssh/authorized_keys
    StrictModes yes
    UsePAM no
    AllowUsers nix-on-droid
    AllowAgentForwarding no
    X11Forwarding no
    PrintMotd no

    SetEnv BASH_ENV=${homeDir}/.bash_env

    Subsystem sftp internal-sftp
  '';

  # ssh 会话的环境：sshd 执行 `bash -c` 时不会读 ~/.bashrc，PATH 只有
  # OpenSSH 的默认值（/usr/bin:/bin:/usr/sbin:/sbin），里面没有 nix。
  # 用 BASH_ENV 让每次非交互命令都先把 ~/.nix-profile/bin 放进 PATH。
  # 注意：这里**不调用 ~/rc**，sshd 不会因为开一个会话被自动拉起。
  home.file.".bash_env".text = ''
    export PATH="$HOME/.nix-profile/bin:$HOME/.nix-profile/sbin:/bin:/usr/bin"
    if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
      . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    fi
  '';

  # ~/.ssh 必须 0700，authorized_keys 必须 0600，否则 StrictModes 拒绝公钥登录。
  # dotfile.nix 把 authorized_keys 软链到仓库文件，chmod 会作用于源文件；
  # git 只记录可执行位，因此不会产生仓库 diff。
  home.activation.sshPermissions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "${homeDir}/.ssh"
    $DRY_RUN_CMD chmod 700 "${homeDir}/.ssh"
    if [ -e "${homeDir}/.ssh/authorized_keys" ]; then
      $DRY_RUN_CMD chmod 600 "${homeDir}/.ssh/authorized_keys"
    fi
  '';
}
