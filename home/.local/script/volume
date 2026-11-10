#!/bin/bash

# 配置常量
SINK="@DEFAULT_AUDIO_SINK@"
STEP=0.05
MAX_VOL=1.5
MIN_VOL=0.0

# 读取当前音量
VOL_RAW=$(wpctl get-volume "$SINK")
VOL=$(echo "$VOL_RAW" | awk '{print $2}')
IS_MUTED=$(echo "$VOL_RAW" | grep -q '\[MUTED\]' && echo 1 || echo 0)

case "$1" in
    up)
        # 升音量：强制解静音，0音量直接跳5%
        wpctl set-mute "$SINK" 0
        if (( $(echo "$VOL <= 0.00" | bc -l) )); then
            wpctl set-volume -l "$MAX_VOL" "$SINK" 5%
        else
            wpctl set-volume -l "$MAX_VOL" "$SINK" "$STEP"+
        fi
        ;;

    down)
        # 降音量，下限0
        NEW_VOL=$(echo "$VOL - $STEP" | bc -l)
        if (( $(echo "$NEW_VOL < $MIN_VOL" | bc -l) )); then
            NEW_VOL=$MIN_VOL
        fi
        wpctl set-volume "$SINK" "$NEW_VOL"
        ;;

    mute)
        # 完全静音
        wpctl set-mute "$SINK" 1
        ;;

    vocal)
        # 取消静音、恢复发声
        wpctl set-mute "$SINK" 0
        ;;

    toggle)
        # 静音切换
        wpctl set-mute "$SINK" toggle
        ;;

    *)
        echo "使用方法："
        echo "  $0 up     音量+5%"
        echo "  $0 down   音量-5%"
        echo "  $0 mute   静音"
        echo "  $0 vocal  取消静音"
        echo "  $0 toggle 切换静音状态"
        exit 1
        ;;
esac

