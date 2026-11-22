git_aliased=0
git_alias() {
    alias clone="command git clone"
    alias remote="command git remote"
    alias checkout="command git checkout"
    alias status="command git status"
    alias pull="command git pull"
    alias diff="command git diff"
    alias add="command git add"
    alias commit="command git commit"
    alias branch="command git branch"
    alias push="command git push"
    alias merge="command git merge"
    alias rebase="command git rebase"
    alias stash="command git stash"
    alias reset="command git reset"

    alias ce="command git clone"
    alias ct="command git checkout"
    alias s="command git status"
    alias p="command git push"
    alias l="command git pull"
    alias d="command git diff"
    alias a="command git add"
    alias c="command git commit"
    alias b="command git branch"
    alias m="command git merge"
    alias r="command git reset"
    alias qp="command git add . && command git commit -am 'update' && command git push -u github main"

    git_aliased=1
}
git_unalias() {
    # 移除长别名
    unalias clone
    unalias remote
    unalias checkout
    unalias status
    unalias pull
    unalias diff
    unalias add
    unalias commit
    unalias branch
    unalias push
    unalias merge
    unalias rebase
    unalias stash
    unalias reset

    # 移除短别名
    unalias ce
    unalias ct
    unalias s
    unalias p
    unalias l
    unalias d
    unalias a
    unalias c
    unalias b
    unalias m
    unalias r
    unalias qp

    git_aliased=0
}
git_is_repo() {
    command git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo 1 || echo 0
}
git_hook_chpwd() {
    # 路径 hook, 变更目录后如果是 git 目录, 定义别名, 否则移除别名
    git_in_work_tree=$(git_is_repo)
    if [[ git_aliased -eq 0 && git_in_work_tree -eq 1 ]] ; then
        git_alias
    elif [[ git_aliased -eq 1 && git_in_work_tree -eq 0 ]] ; then
        git_unalias
    fi
}
git_hook_chpwd
# chpwd钩子
if [ -n "$ZSH_VERSION" ]; then
    eval '
    if [[ -z ${chpwd_functions[(r)git_hook_chpwd]} ]]; then
        add-zsh-hook -Uz chpwd git_hook_chpwd
    fi
    '
elif [ -n "$BASH_VERSION" ]; then
    __last_pwd="$PWD"
    __chpwd_dispatch() {
        if [[ "$PWD" != "$__last_pwd" ]]; then
            __last_pwd="$PWD"
            git_hook_chpwd
        fi
    }
    if [[ ! " ${precmd_functions[*]} " == *" __chpwd_dispatch "* ]]; then
        precmd_functions+=(__chpwd_dispatch)
    fi
fi

# 使用git init的目录别名不生效时除了新开terminal也可以`.`一下(cd ./)
# 注意：函数内部必须用 `command git` 绕过 alias git=git_init_process，
# 否则本文件被重复 source（alias 已生效）时函数体里的 git 会被展开成自身，
# 造成无限递归并报 "maximum nested function level reached; increase FUNCNEST?"。
git_init_process() {
    if [ "$1" = 'init' ]; then
        command git "$@" && cd ./
    else
        command git "$@"
    fi
}
alias git="git_init_process"
