
注意: 还没有编译**成功过**的话配置的国内源就**生效不了**, 因此第一次编译/switch最好在命令中显式指定国内源防止因网络问题导致失败: 
``` bash
home-manager switch --flake ~/.local/project/home-manager \
  --option substituters "https://mirrors.cernet.edu.cn/nix-channels/store?priority=10 https://mirrors.ustc.edu.cn/nix-channels/store?priority=10 https://mirror.sjtu.edu.cn/nix-channels/store?priority=10 https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=20 https://cache.nixos.org/"
```
或者也可以先注释掉其他包的安装, 单独为国内源编译一次配置, 让国内源先生效

## begonia 上的 switch 必须在应用终端里跑

`nix-on-droid switch` 要走应用自身终端（untrusted_app 域）。经 Termux `su` 以 root 域执行会生成 `u:object_r:app_data_file:s0` 标签、缺少 MLS categories，应用侧读不到软链与 store 路径，表现为 proot 报 `'.../usr/bin/sh' not found`。修复：
```bash
chcon -R -h u:object_r:app_data_file:s0:c164,c257,c512,c768 /data/data/com.termux.nix/files
```
