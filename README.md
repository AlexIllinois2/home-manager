
注意: 还没有编译**成功过**的话配置的国内源就**生效不了**, 因此第一次编译最好在命令中显式指定国内源: 
``` bash
home-manager switch --flake ~/.local/project/home-manager \
  --option substituters "https://mirrors.cernet.edu.cn/nix-channels/store?priority=10 https://mirrors.ustc.edu.cn/nix-channels/store?priority=10 https://mirror.sjtu.edu.cn/nix-channels/store?priority=10 https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=20 https://cache.nixos.org/"
```
或者也可以先注释掉其他包的安装, 单独为国内源编译一次配置, 让国内源先生效


``` bash

# 测试构建
home-manager build --flake ~/.local/project/home-manager
```