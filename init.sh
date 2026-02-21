#! /bin/bash
set -euo pipefail

# 暂时只适配debian系
apt install -y \
    liblua5.4-0 \
    liblua5.4-dev \
    luarocks

luarocks-5.4 install lualogging 
luarocks-5.4 install luaposix 
luarocks-5.4 install ansicolors 
luarocks-5.4 install luafilesystem