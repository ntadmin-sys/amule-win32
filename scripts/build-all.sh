#!/bin/bash

set -e

help_msg="Usage: ./scripts/build-all.sh -arch=[x86|x86_64|arm32|arm64] -cc=[gcc|clang]"

if [ $# == 2 ]; then
    for option in "$@"; do
        case "$option" in
            -arch=x86)
                ARCH=win32
                ;;
            -arch=x86_64)
                ARCH=win64
                ;;
            -arch=arm32)
                ARCH=win32-arm
                ;;
            -arch=arm64)
                ARCH=win64-arm
                ;;
            -cc=gcc)
                USE_LLVM=no
                ;;
            -cc=clang)
                USE_LLVM=yes
                ;;
            *)
                echo "$help_msg"
                exit 1
                ;;
        esac
    done
else
    echo "$help_msg"
    exit 1
fi

# 设置工具链路径和目标三元组
if [ "$USE_LLVM" == "yes" ]; then
    TOOLCHAIN_PATH="$PWD/toolchain/clang/bin"
    if [ "$ARCH" == "win32" ]; then
        TARGET=i686-w64-mingw32
    elif [ "$ARCH" == "win64" ]; then
        TARGET=x86_64-w64-mingw32
    elif [ "$ARCH" == "win32-arm" ]; then
        TARGET=armv7-w64-mingw32
    elif [ "$ARCH" == "win64-arm" ]; then
        TARGET=aarch64-w64-mingw32
    fi
else
    if [ "$ARCH" == "win32" ] || [ "$ARCH" == "win32-arm" ]; then
        TOOLCHAIN_PATH="$PWD/toolchain/mingw32/bin"
        if [ "$ARCH" == "win32" ]; then
            TARGET=i686-w64-mingw32
        else
            TARGET=armv7-w64-mingw32
        fi
    elif [ "$ARCH" == "win64" ] || [ "$ARCH" == "win64-arm" ]; then
        TOOLCHAIN_PATH="$PWD/toolchain/mingw64/bin"
        if [ "$ARCH" == "win64" ]; then
            TARGET=x86_64-w64-mingw32
        else
            TARGET=aarch64-w64-mingw32
        fi
    else
        echo "Unsupported ARCH: $ARCH"
        exit 1
    fi
fi

PATH="$TOOLCHAIN_PATH:$PATH"

BUILDDIR="$PWD/build-$ARCH"

# 检查编译器是否存在
if ! command -v "${TARGET}-g++" &> /dev/null; then
    echo "${TARGET}-g++ is not found in PATH!"
    echo "PATH=$PATH"
    exit 2
fi
echo "Using compiler: ${TARGET}-g++"

# 导出环境变量
export PATH
export TARGET
export BUILDDIR
export USE_LLVM
export ARCH

# PKG_CONFIG 设置
export PKG_CONFIG_LIBDIR="$BUILDDIR/libpng/lib/pkgconfig:$BUILDDIR/zlib/lib/pkgconfig:$BUILDDIR/libgd/lib/pkgconfig:$BUILDDIR/libiconv/lib/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
export PKG_CONFIG_SYSROOT_DIR="$BUILDDIR"
export CXXFLAGS="-g0 -O2"
export CFLAGS="-g0 -O2"
export CPPFLAGS="-I$BUILDDIR/libiconv/include -I$BUILDDIR/zlib/include -I$BUILDDIR/libpng/include -I$BUILDDIR/gettext/include -Wno-error=register -Wno-error=incompatible-pointer-types"
export LDFLAGS="-L$BUILDDIR/libiconv/lib -L$BUILDDIR/zlib/lib -L$BUILDDIR/libpng/lib -L$BUILDDIR/gettext/lib -s --static"

# 创建输出目录
mkdir -p amule
mkdir -p amule-dlp

# 构建依赖
./scripts/zlib.sh
./scripts/libpng.sh
./scripts/libiconv.sh
./scripts/gettext.sh
./scripts/geoip.sh
./scripts/libupnp.sh

# x86_64 也需要 mbedtls 和 CA bundle（建议保留）
if [ "$ARCH" == "win32" ] || [ "$ARCH" == "win64" ]; then
    ./scripts/mbedtls.sh
    wget https://curl.se/ca/cacert.pem -O curl-ca-bundle.crt
    cp curl-ca-bundle.crt amule/
    cp curl-ca-bundle.crt amule-dlp/
fi

./scripts/curl.sh
./scripts/cryptopp-autotools.sh
./scripts/wxwidgets.sh
./scripts/boost.sh
./scripts/libgd.sh
./scripts/amule.sh
./scripts/amule-dlp.sh

# 清理临时目录
rm -rf amule-dlp
rm -rf amule
