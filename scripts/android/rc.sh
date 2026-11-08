#!/bin/sh
# ~/rc —— 由 home-manager 声明式生成（见 hosts/xplay6.nix 的 home.file."rc"）。
#
# 用途：Nix-on-Droid 应用每次打开终端都会启动 login shell。设备 /etc/passwd 里
# nix-on-droid 用户的 shell 是 bash-interactive，login-inner 以 0 参数时
# `exec -a "-bash"` 启动它（见 nix-on-droid 源码
# modules/environment/login/login-inner.nix），也就是“登录 shell”。
# 登录 shell 必读 ~/.bash_profile，而 ~/.bash_profile 会调用本脚本。
# 于是“应用开终端”=“拉起 proot 内的 sshd”，不需要 adb、不需要手动执行。
#
# 边界（重要）：
#   * 纯 app 身份（uid 10140 / untrusted_app），不 su、不 setcon、不写 sysfs；
#   * 不是 Android 开机自启：重启后仍需打开一次应用；应用被系统杀掉后，
#     重新打开应用（即再开一个终端）就会自动恢复；
#   * 与设备上的临时 root（/data/adb）完全无关，任何时候都能运行。

# 1) 非交互场景直接退出。
#    注意：不能只写 `case $- in *i*)`。本脚本是被 ~/.bash_profile 以独立进程
#    执行的（shebang 是 /bin/sh），此时 $- 描述的是脚本自己的 sh，永远不含 i，
#    会把“应用开终端”也一并跳过（实测就是这样把 sshd 漏掉的）。
#    所以：被 source 时看 $-；被独立执行时看 stdin 是不是终端（应用终端是 pty）。
case $- in
  *i*) ;;
  *) [ -t 0 ] || exit 0 ;;
esac

# 2) 已经在 ssh 会话里：sshd 必然在跑，省掉探测与启动。
[ -n "${SSH_CONNECTION:-}" ] && exit 0

HOME=${HOME:-/data/data/com.termux.nix/files/home}
RC_LOG="$HOME/rc.log"
SSHD_APP="$HOME/.config/home-manager/scripts/android/sshd-app.sh"
LOCK="$HOME/.rc.lock"
PIDFILE="$HOME/.ssh/sshd.pid"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$RC_LOG" 2>/dev/null
}

# 3) 端口探测。这台设备上没有 ss/netstat/lsof/awk/grep，直接读 /proc/net/tcp：
#    第 2 列 local_address（hex，末 4 位是端口），第 4 列状态，0A = LISTEN。
#    2222 十进制 = 0x08AE。
port_listening() {
  for _f in /proc/net/tcp /proc/net/tcp6; do
    [ -r "$_f" ] || continue
    while read -r _sl _local _rem _st _rest; do
      case $_local in
        *:08AE) [ "$_st" = 0A ] && return 0 ;;
      esac
    done <"$_f" 2>/dev/null
  done
  return 1
}

# pidfile 存活判断，作为 /proc 不可读时的兜底。
pid_alive() {
  [ -r "$PIDFILE" ] || return 1
  _pid=$(cat "$PIDFILE" 2>/dev/null) || return 1
  [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null
}

already_up() { port_listening || pid_alive; }

already_up && exit 0

# 4) 互斥：同时打开多个终端（或连续快速打开）时，只允许一个实例去启动 sshd。
#    用 `ln -s "$$"` 一步原子地“创建锁 + 写入持有者 pid”：先 mkdir 再写 pid 会有
#    “目录已存在但 pid 还没写进去”的空窗，5 个并发实测能同时抢到（3 个 sshd 争
#    2222，两个报 Address already in use）。符号链接把 pid 放在链接目标里，没有空窗。
release_lock() { rm -rf "$LOCK" 2>/dev/null; }

acquire_lock() {
  ln -s "$$" "$LOCK" 2>/dev/null && {
    trap 'release_lock' EXIT HUP INT TERM
    return 0
  }
  _holder=$(readlink "$LOCK" 2>/dev/null)
  if [ -n "$_holder" ] && kill -0 "$_holder" 2>/dev/null; then
    return 1
  fi
  # 持有者已死：清理陈旧锁后重试一次。
  rm -rf "$LOCK" 2>/dev/null
  ln -s "$$" "$LOCK" 2>/dev/null || return 1
  trap 'release_lock' EXIT HUP INT TERM
  return 0
}

acquire_lock || exit 0

# 拿到锁后再确认一次：另一个 rc 可能刚好已经把 sshd 拉起来了。
already_up && exit 0

# 5) 后台启动，不阻塞当前 shell。sshd-app.sh 自己会 exec sshd（sshd 再 daemonize），
#    启动输出与失败原因都追加到 ~/rc.log。
log "sshd not listening on 2222; starting via sshd-app.sh"
( "$SSHD_APP" >>"$RC_LOG" 2>&1 & )

exit 0
