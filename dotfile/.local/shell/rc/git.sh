git_aliased=0
git_alias() {
    alias clone="git clone"
    alias remote="git remote"
    alias checkout="git checkout"
    alias status="git status"
    alias pull="git pull"
    alias diff="git diff"
    alias add="git add"
    alias commit="git commit"
    alias branch="git branch"
    alias push="git push"
    alias merge="git merge"
    alias rebase="git rebase"
    alias stash="git stash"
    alias reset="git reset"

    alias ce="git clone"
    alias ct="git checkout"
    alias s="git status"
    alias p="git push"
    alias l="git pull"
    alias d="git diff"
    alias a="git add"
    alias c="git commit"
    alias b="git branch"
    alias m="git merge"
    alias r="git reset"
    alias qp="git add . && git commit -am 'update' && git push -u github main"

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
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo 1 || echo 0
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
git_init_process() {
    if [ "$1" = 'init' ]; then
        git "$@" && cd ./
    else
        git "$@"
    fi
}
alias git="git_init_process"
