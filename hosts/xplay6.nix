{
  pkgs,
  lib,
  ...
}:
let
  # 设备侧 sshd（方案 B）的唯一端口来源：改这里即可，其余脚本引用同一常量。
  sshPort = 2222;
  homeDir = "/data/data/com.termux.nix/files/home";
in
{
  imports = [
    ../pkg/xplay6-toolchain.nix
  ];

  # Nix-on-Droid 的固定布局：proot 内 HOME 为 /data/data/com.termux.nix/files/home
  home.username = lib.mkForce "nix-on-droid";
  home.homeDirectory = lib.mkForce homeDir;

  # Android 上没有 /usr/bin/sudo、/usr/bin/chsh 与 /etc/shells，
  # zsh.nix 中的默认 shell 切换一定会失败，这里直接禁用该 activation。
  home.activation.makeZshDefault = lib.mkForce (lib.hm.dag.entryAfter [ "writeBoundary" ] "");

  # 设备上没有桌面环境与输入法，不加载相关 shell 片段
  dotfiles.exclude = [
    "fcitx5.sh"
    "gnome.sh"
  ];

  # 打包工具链（JDK/Gradle/apksigner/adb/Rust/Node），见 pkg/xplay6-toolchain.nix
  # 以及 proot 内 sshd 所需的 openssh。
  home.packages = with pkgs; [ openssh ];

  # 设备侧使用说明（纯 app 身份，无 root 依赖）：
  #   - sshd 以 uid 10140 在 proot 内运行，不做 setuid/setcon，不依赖 /sbin/su。
  #   - 自动启动：打开 Nix-on-Droid 应用就会开一个 login shell（bash），
  #     login shell 读 ~/.bash_profile，后者调用 ~/rc，~/rc 再把 sshd 拉起来。
  #     所以“应用开终端”即“sshd 已就绪”，不需要 adb、不需要手动执行脚本。
  #   - 没有 Android 开机自启（设备上无 systemd，也不做 su 钩子）。
  #     重启或应用被系统杀掉后，只需重新打开一次应用（开终端）即自动恢复。
  #   - CPU 锁频/Doze 白名单需要“当前会话有临时 root”，只作为手动脚本保留：
  #       ~/.config/home-manager/scripts/android/cpu-boost-manual.sh
  #     它不在任何自动路径上（无开机钩子、无 HM activation、无登录自动调用）。
  #
  # proot 内的 sshd 配置。host key 不在 store 里，放在持久 home 目录，
  # 由 scripts/android/sshd-app.sh 在首次启动时生成。
  #
  # SetEnv BASH_ENV：sshd 执行 `bash -c` 时不会读 ~/.bashrc，PATH 只有
  # OpenSSH 的默认值（/usr/bin:/bin:/usr/sbin:/sbin），里面没有 nix。
  # 用 BASH_ENV 让每次非交互命令都先把 ~/.nix-profile/bin 放进 PATH。
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

  # ssh 会话的环境：非交互命令靠 BASH_ENV，交互式靠 .bash_profile/.bashrc。
  home.file.".bash_env".text = ''
    export PATH="$HOME/.nix-profile/bin:$HOME/.nix-profile/sbin:/bin:/usr/bin"
    if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
      . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    fi
  '';

  # ~/rc：登录 shell 的自动入口。挂载点是 ~/.bash_profile（见下方），由
  # login-inner 启动登录 shell 时必然读取；内容见 scripts/android/rc.sh。
  home.file."rc" = {
    source = ../scripts/android/rc.sh;
    executable = true;
  };

  # 打开 Nix-on-Droid 应用时，login-inner 会以 0 参数启动登录 shell（bash），
  # 于是 .bash_profile 就是“应用启动”的必然入口。它只负责调 ~/rc，
  # 是否真的要起 sshd 由 ~/rc 自己判断（幂等、加锁、非交互跳过）。
  home.file.".bash_profile".text = ''
    . "$HOME/.bash_env"
    [ -x "$HOME/rc" ] && "$HOME/rc"
  '';

  # 交互式非登录 shell（例如在终端里再敲 bash）走 .bashrc，同样接上 ~/rc。
  # ~/rc 内部做了幂等判断，重复调用不会起第二个 sshd。
  home.file.".bashrc".text = ''
    . "$HOME/.bash_env"
    [ -x "$HOME/rc" ] && "$HOME/rc"
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
