#! /bin/bash
set -euo pipefail

# 暂时只适配debian系
apt install -y \
    lua5.4 \
    lua-logging \
    lua-posix \
    lua-ansicolors \
    lua-filesystem