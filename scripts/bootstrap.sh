#!/usr/bin/env bash
# Trabalho 1 - Compiladores: bootstrap da toolchain local do projeto.
# Compila em .tools/ o que estiver faltando no sistema (flex e, se preciso, bison),
# para que "mise run build/test" funcione sem instalar nada globalmente.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$ROOT/.tools"
SRC="$TOOLS/src"

FLEX_VERSION=2.6.4
FLEX_URL="https://github.com/westes/flex/releases/download/v${FLEX_VERSION}/flex-${FLEX_VERSION}.tar.gz"
FLEX_SHA256=e87aae032bf07c26f85ac0ed3250998c37621d95f8bd748b31f15b33c45ee995

BISON_VERSION=3.8.2
BISON_URL="https://ftp.gnu.org/gnu/bison/bison-${BISON_VERSION}.tar.gz"
BISON_SHA256=06c9e13bdf7eb24d4ceb6b59205a4f67c2c7e7213119644430fe82fbd14a0abb

mkdir -p "$SRC" "$TOOLS/bin"

fetch() { # fetch <url> <destino> <sha256>
    local url=$1 dest=$2 sha=$3
    if [ ! -f "$dest" ]; then
        echo ">> baixando $(basename "$dest")"
        curl -fsSL -o "$dest" "$url"
    fi
    echo "$sha  $dest" | sha256sum -c - >/dev/null
}

if ! "$TOOLS/bin/flex" --version >/dev/null 2>&1; then
    echo ">> compilando flex $FLEX_VERSION em .tools/ (~1 min)"
    fetch "$FLEX_URL" "$SRC/flex-$FLEX_VERSION.tar.gz" "$FLEX_SHA256"
    rm -rf "$SRC/flex-$FLEX_VERSION"
    tar -xzf "$SRC/flex-$FLEX_VERSION.tar.gz" -C "$SRC"
    (
        cd "$SRC/flex-$FLEX_VERSION"
        # -D_GNU_SOURCE: o tarball 2.6.4 precisa disso para reallocarray em glibc recentes
        ./configure --prefix="$TOOLS" --disable-nls CFLAGS="-g -O2 -D_GNU_SOURCE" >configure.log 2>&1
        # compila/instala apenas src/ (evita regenerar docs, que exigiria help2man)
        make -C src -j"$(nproc)" >build.log 2>&1
        make -C src install >install.log 2>&1
    )
fi
"$TOOLS/bin/flex" --version

# bison: usa o do sistema se for >= 3.0; senao compila localmente
bison_ok() { command -v "$1" >/dev/null 2>&1 && "$1" --version | head -1 | grep -qE ' (3|[4-9])\.'; }
if bison_ok "$TOOLS/bin/bison"; then
    "$TOOLS/bin/bison" --version | head -1
elif bison_ok bison; then
    bison --version | head -1
else
    echo ">> compilando bison $BISON_VERSION em .tools/ (~2 min)"
    fetch "$BISON_URL" "$SRC/bison-$BISON_VERSION.tar.gz" "$BISON_SHA256"
    rm -rf "$SRC/bison-$BISON_VERSION"
    tar -xzf "$SRC/bison-$BISON_VERSION.tar.gz" -C "$SRC"
    (
        cd "$SRC/bison-$BISON_VERSION"
        ./configure --prefix="$TOOLS" --disable-nls >configure.log 2>&1
        make -j"$(nproc)" >build.log 2>&1
        make install >install.log 2>&1
    )
    "$TOOLS/bin/bison" --version | head -1
fi

echo ">> toolchain pronta"
