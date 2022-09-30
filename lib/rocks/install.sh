#! /usr/bin/env zsh

if [ ! $(command -v luarocks) ]; then
    echo "luarocks not found, check your lua installation then retry."
    exit 1
fi

zmodload zsh/zutil
zparseopts -F -- \
    -lua_ver:=lua_ver \
    -tree:=tree \
    -libs:=libs ||
    return 1

lua_ver=$lua_ver[-1]
tree=$tree[-1]
libs=(${(@s:,:)libs[-1]})

for lib in ${libs[@]}
do
    luarocks install --lua-version $lua_ver --tree $tree $lib
done