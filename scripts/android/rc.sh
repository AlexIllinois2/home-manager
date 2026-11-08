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
# sshd 自己只写 pid（PidFile），不写启动时间；这里额外记一份 “pid 启动时间”，
# 用来抵御 Android 的 PID 复用（仅凭 kill -0 会把复用后的陌生进程当成 sshd）。
METAFILE="$HOME/.ssh/sshd.pid.meta"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$RC_LOG" 2>/dev/null
}

# 3) 端口探测。这台设备上没有 ss/netstat/lsof，直接读 /proc/net/tcp：
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

# 读取某进程的启动时间（/proc/<pid>/stat 第 22 字段）。
# PID 被复用时该进程的 starttime 与旧记录必然不同，因此它能区分“同一个 pid
# 号”和“同一个进程”。删掉 “pid (comm) ” 前缀后，starttime 变成第 20 字段；
# 不用 awk/grep，避免依赖（脚本可能在没有 profile 的环境里执行）。
proc_start() {
  [ -r "/proc/$1/stat" ] || return 1
  _line=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
  _line=${_line##*) }
  set -- $_line
  [ $# -ge 20 ] || return 1
  eval "_st=\${20}"
  printf '%s' "$_st"
}

# pidfile 里的 pid 必须真的是 sshd（/proc/<pid>/comm = sshd）；
# 有 METAFILE 时还要求启动时间一致。任何一项不满足都算陈旧。
pid_alive() {
  _pid=$(cat "$PIDFILE" 2>/dev/null) || return 1
  case $_pid in '' | *[!0-9]*) return 1 ;; esac
  [ -r "/proc/$_pid/comm" ] || return 1
  [ "$(cat "/proc/$_pid/comm" 2>/dev/null)" = sshd ] || return 1
  _st=$(proc_start "$_pid") || return 1
  if [ -r "$METAFILE" ]; then
    read -r _mpid _mst <"$METAFILE" 2>/dev/null || return 1
    if [ "$_mpid" = "$_pid" ]; then
      # 同一个 pid 号但启动时间不同 → PID 被复用，pidfile 是陈旧的。
      [ "$_mst" = "$_st" ] || return 1
    else
      # meta 属于更早的一代 sshd，pidfile 本身仍可能是活的：以当前进程刷新。
      printf '%s %s\n' "$_pid" "$_st" >"$METAFILE" 2>/dev/null || true
    fi
  fi
  return 0
}

# 端口没监听且 pidfile 不可信：清掉陈旧 pidfile / meta，让后续启动继续。
drop_stale_pidfile() {
  [ -e "$PIDFILE" ] || [ -e "$METAFILE" ] || return 0
  log "removing stale pidfile/meta (pid=$(cat "$PIDFILE" 2>/dev/null))"
  rm -f "$PIDFILE" "$METAFILE"
}

# 第一判据是端口；端口读不到/未监听时才看 pidfile，并且只认真正的 sshd。
already_up() {
  port_listening && return 0
  pid_alive && return 0
  drop_stale_pidfile
  return 1
}

already_up && exit 0

# 4) 互斥：同时打开多个终端（或连续快速打开）时，只允许一个实例去启动 sshd。
#    用 `ln -s` 一步原子地“创建锁 + 写入持有者标识”：先 mkdir 再写 pid 会有
#    “目录已存在但 pid 还没写进去”的空窗，5 个并发实测能同时抢到（3 个 sshd 争
#    2222，两个报 Address already in use）。
#    锁目标是 "pid:starttime"；starttime 用来识别“pid 号被复用给别的进程”，
#    这种情况下锁其实已经失效，必须能清理重抢，否则 sshd 永远起不来。
release_lock() { rm -rf "$LOCK" 2>/dev/null; }

self_start=$(proc_start "$$" 2>/dev/null || true)
self_start=${self_start:-?}

acquire_lock() {
  ln -s "$$:$self_start" "$LOCK" 2>/dev/null && {
    trap 'release_lock' EXIT HUP INT TERM
    return 0
  }
  _holder=$(readlink "$LOCK" 2>/dev/null)
  case $_holder in
    *:*)
      _hp=${_holder%%:*}
      _hs=${_holder#*:}
      if [ -n "$_hp" ] && kill -0 "$_hp" 2>/dev/null; then
        _hst=$(proc_start "$_hp" 2>/dev/null || true)
        [ "$_hst" = "$_hs" ] && return 1
      fi
      ;;
    *)
      # 旧格式（只有 pid，没有 starttime）：无法判断持有者身份，一律视为陈旧。
      # 旧锁一旦残留（持有者被杀、pid 被复用）就会永久挡住新 rc，此时宁可
      # 清掉重抢；即便误抢，竞争的一方也只是 sshd 报 “Address already in use”，
      # 不影响已经起来的那个。
      ;;
  esac
  log "removing stale lock ($_holder)"
  # 持有者已死 / pid 被复用 / 旧格式残留：清理后重试一次。
  rm -rf "$LOCK" 2>/dev/null
  ln -s "$$:$self_start" "$LOCK" 2>/dev/null || return 1
  trap 'release_lock' EXIT HUP INT TERM
  return 0
}

acquire_lock || exit 0

# 拿到锁后再确认一次：另一个 rc 可能刚好已经把 sshd 拉起来了。
already_up && exit 0

# 5) 后台启动，不阻塞当前 shell。sshd-app.sh 自己会 exec sshd（sshd 再 daemonize），
#    启动输出与失败原因都追加到 ~/rc.log。
#    用 `sh` 调起而不是直接执行：这个文件不经 home.file 管理，靠 rsync 落地，
#    一旦丢了可执行位（实测发生过，rc 会静默 Permission denied），sh 仍能跑。
log "sshd not listening on 2222; starting via sshd-app.sh"
( sh "$SSHD_APP" >>"$RC_LOG" 2>&1 & )

# sshd daemonize 之后会写 PidFile。等它出现，把 “pid 启动时间” 记到 METAFILE，
# 供下次 rc 判断是否被 PID 复用；最多等 3 秒，等不到就交给下一轮端口探测。
_i=0
while [ "$_i" -lt 3 ]; do
  if [ -r "$PIDFILE" ]; then
    _p=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$_p" ] && [ "$(cat "/proc/$_p/comm" 2>/dev/null)" = sshd ]; then
      _s=$(proc_start "$_p" 2>/dev/null || true)
      if [ -n "$_s" ]; then
        printf '%s %s\n' "$_p" "$_s" >"$METAFILE"
        log "sshd started (pid $_p start $_s)"
        break
      fi
    fi
  fi
  _i=$((_i + 1))
  sleep 1
done

exit 0
