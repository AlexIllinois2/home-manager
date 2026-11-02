export BIN_PATH=${HOME}/.local/bin
export SCRIPT_PATH=${HOME}/.local/script
export APP_IMAGE_PATH=${HOME}/.local/appimage
export _LD_LIBRARY_PATH=${HOME}/.local/lib

export PATH=$SCRIPT_PATH:$BIN_PATH:$APP_IMAGE_PATH:$_LD_LIBRARY_PATH:/usr/local/bin:$PATH
if [[ "$(uname -o)" != "Android" ]]; then
  export LD_LIBRARY_PATH=${_LD_LIBRARY_PATH}:$LD_LIBRARY_PATH
fi
