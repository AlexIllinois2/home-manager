#!/bin/sh
# 在 Nix-on-Droid 的 proot 会话里启动 sshd —— 纯 app 身份（uid 10140），
# 不需要 root、不 setuid、不 setcon、不依赖 /sbin/su。
#
# 用法（重启后必须人工执行，没有开机自启）：
#   1. 打开 Nix-on-Droid 应用，进入它的终端（此时已是 uid 10140 的 proot 会话）
#   2. 执行：~/.config/home-manager/scripts/android/sshd-app.sh
#
# 端口 2222、host key、authorized_keys 的位置都在 hosts/xplay6.nix 里定义，
# 本脚本只做“生成 key（首次）→ 检查是否已在跑 → 启动”。
# 生命周期：sshd 跟着 Nix-on-Droid 的应用进程走；应用被系统杀掉后需要重开应用再跑一次。
set -u

export HOME=/data/data/com.termux.nix/files/home
export USER=nix-on-droid
export PATH="$HOME/.nix-profile/bin:/bin:/usr/bin"
export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export TMPDIR=/tmp

KEY="$HOME/.ssh/ssh_host_ed25519_key"
CONF="$HOME/.ssh/sshd_config"
PID="$HOME/.ssh/sshd.pid"
LOG="$HOME/.ssh/sshd.log"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# host key 持久保存在 home 里（不会被 nix-on-droid switch 冲掉，也不在 /nix/store）。
if [ ! -f "$KEY" ]; then
  echo "generating host key $KEY"
  ssh-keygen -t ed25519 -N "" -f "$KEY" -C "xplay6@nix-on-droid"
fi
chmod 600 "$KEY"
[ -f "$KEY.pub" ] && chmod 600 "$KEY.pub"
[ -e "$HOME/.ssh/authorized_keys" ] && chmod 600 "$HOME/.ssh/authorized_keys"

if [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
  echo "sshd already running (pid $(cat "$PID"))"
  exit 0
fi

# sshd 的 re-exec 要求 argv[0] 是绝对路径；proot 下 command -v 给的是
# /nix/store/...，readlink -f 再取一次真实路径。
BIN=$(readlink -f "$(command -v sshd)")
echo "starting sshd: $BIN (uid $(id -u), selinux $(tr -d '\000' < /proc/self/attr/current 2>/dev/null))"
exec "$BIN" -f "$CONF" -E "$LOG"
