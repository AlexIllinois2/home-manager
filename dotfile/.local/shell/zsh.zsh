
# 允许输入行注释
setopt interactive_comments

## plugins
# 自动跳转(关闭警告)
zmodload zsh/zle
export _ZO_DOCTOR=0

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

## 基于上键的历史命令筛选
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
# 使用 terminfo（安全写法）
if (( ${+terminfo[kcuu1]} )); then
  bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search
fi
if (( ${+terminfo[kcud1]} )); then
  bindkey "${terminfo[kcud1]}" down-line-or-beginning-search
fi
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
# 配置补全样式：不区分大小写
# 'm:{a-zA-Z}={A-Za-z}' 表示将小写映射为大写，大写映射为小写，实现双向忽略
# 'r:|[._-]=* r:|=*' 等后续参数用于增强模糊匹配的灵活性
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

## 自定义 widget：清屏 + 清空滚动缓冲区（保留命令历史, 但输出永久消失）
clear-screen-and-scrollback() {
  # 1. 清可见屏 + 清滚动区（核心）
  printf '\e[H\e[2J\e[3J'
  # 2. 重绘提示符（避免光标/提示符错位）
  zle .reset-prompt
  zle -R
}
# 注册 widget
zle -N clear-screen-and-scrollback
# 绑定到 Ctrl+L（覆盖默认）
bindkey '^L' clear-screen-and-scrollback

# 添加钩子供自定义脚本使用
autoload -U add-zsh-hook