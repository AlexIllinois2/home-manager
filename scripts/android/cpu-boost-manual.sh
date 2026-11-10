#!/system/bin/sh
# 手动 CPU 锁频 + 保活白名单（需要“当前会话有临时 root”，即 /sbin/su 应答 uid=0）。
#
# 本脚本不挂在任何自动路径上：没有开机钩子、没有 HM activation、没有登录自动调用。
# 所有效果都是 RAM 态 / 系统设置态，重启后全部丢失，需要重新执行。
#
# 用法（在有 root 的 shell 里，例如 Termux 打开后 su）：
#   su -c sh /data/data/com.termux.nix/files/home/.config/home-manager/scripts/android/cpu-boost-manual.sh
#
# 说明：xplay6 的 4 个核默认 governor 就是 performance，且 min=max=cpuinfo_max_freq；
# 本脚本的作用是“被厂商/热控改回去之后重新压回最高频”，不是必需的常驻服务。
#
# 警告：**绝不能写 scaling_governor**。这台 3.18 内核的 cpufreq interactive
# governor 在切换（GOV_START/STOP）路径上有 Kernel BUG，写 governor 会直接
# panic 重启（实测 2026-11-10，PC=cpufreq_governor_interactive+0x50）。
# 锁频只写 scaling_max/min_freq，不触发 governor 切换，是安全的。
set -e

[ "$(id -u)" = "0" ] || { echo "cpu-boost-manual: 需要临时 root" >&2; exit 1; }

for c in /sys/devices/system/cpu/cpu*/cpufreq; do
  [ -d "$c" ] || continue
  if [ -r "$c/cpuinfo_max_freq" ] && [ -w "$c/scaling_max_freq" ]; then
    max=$(cat "$c/cpuinfo_max_freq")
    echo "$max" > "$c/scaling_max_freq"
    echo "$max" > "$c/scaling_min_freq"
  fi
  echo "$c governor=$(cat "$c/scaling_governor" 2>/dev/null) min=$(cat "$c/scaling_min_freq" 2>/dev/null) max=$(cat "$c/scaling_max_freq" 2>/dev/null)"
done

cmd deviceidle whitelist +com.termux.nix >/dev/null 2>&1 || true
cmd appops set com.termux.nix RUN_IN_BACKGROUND allow >/dev/null 2>&1 || true
cmd appops set com.termux.nix WAKE_LOCK allow >/dev/null 2>&1 || true
settings put global wifi_sleep_policy 2 >/dev/null 2>&1 || true
echo "boost applied (RAM 态，重启即失效)"
