# 新交互式终端打开时，自动切换到英文输入法
if [[ $- == *i* ]]; then
    # 检查 fcitx5-remote 是否存在且可执行
    if command -v fcitx5-remote >/dev/null 2>&1; then
        fcitx5-remote -c
    fi
fi
