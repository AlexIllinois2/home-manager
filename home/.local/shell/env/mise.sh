
if command -v mise >/dev/null 2>&1; then
    export PATH="${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:$PATH"
fi
