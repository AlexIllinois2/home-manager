#!/system/bin/sh
# 一次性清理：删除我们曾用临时 root 放进去的开机钩子。
# 必须 root（临时 root 手动提权后可用一次）；不做任何其他事。
#
# 用法：
#   su -c sh /data/data/com.termux.nix/files/home/.config/home-manager/scripts/android/remove-root-hooks.sh
#
# 做的事：
#   1. 备份 /data/adb/service.d/xplay6-start.sh 到本机仓库外的备份目录
#   2. 删除该文件；若目录为空则一并删掉（避免留下空目录）
#   3. 打印残留检查结果（/data/adb/service.d、/data/local/tmp 下我们自己的脚本）
set -e

[ "$(id -u)" = "0" ] || { echo "remove-root-hooks: 需要临时 root" >&2; exit 1; }

HOOK=/data/adb/service.d/xplay6-start.sh
BACKUP=/data/local/tmp/xplay6-root-hooks-backup

mkdir -p "$BACKUP"
if [ -f "$HOOK" ]; then
  cp -a "$HOOK" "$BACKUP/service.d-xplay6-start.sh.bak"
  echo "backed up: $BACKUP/service.d-xplay6-start.sh.bak"
  rm -f "$HOOK"
  echo "removed: $HOOK"
else
  echo "not present: $HOOK"
fi
if [ -d /data/adb/service.d ]; then
  rmdir /data/adb/service.d 2>/dev/null && echo "removed empty /data/adb/service.d" || true
fi

echo "--- remaining checks ---"
ls -la /data/adb/service.d 2>&1 || true
ls -la /data/local/tmp 2>&1 | grep -E 'xplay6|proot|as-nod|sshd' || true
echo "done"
