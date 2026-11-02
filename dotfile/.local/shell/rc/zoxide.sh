
[[ -o interactive ]] || return

if [ -n "$ZSH_VERSION" ]; then
    eval "$(zoxide init zsh --cmd cd)"
elif [ -n "$BASH_VERSION" ]; then
    eval "$(zoxide init bash --cmd cd)"
fi

cd() {
    __zoxide_z "$@" && ls -a
}
cd .

# cd
alias ~="cd $HOME"
alias ..="cd ../"
alias ...="cd ../../"
alias ....="cd ../../../"
alias .....="cd ../../../../"
alias ......="cd ../../../../../"
