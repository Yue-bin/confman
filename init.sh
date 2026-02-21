#! /bin/bash
set -euo pipefail

# 暂时只适配debian系
apt install -y lua5.4 \
    luarocks

luarocks-5.4 install lualogging 
luarocks-5.4 install luaposix 
luarocks-5.4 install ansicolors 
luarocks-5.4 install luafilesystem