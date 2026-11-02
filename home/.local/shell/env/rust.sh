if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"

export RUST_MIN_STACK=16777216
