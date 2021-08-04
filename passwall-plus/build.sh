#!/bin/bash
export PATH=$PATH:${1}

echo 开始编译 simple-obfs
cd ${4}
git clone --depth 1 https://github.com/shadowsocks/simple-obfs
cd simple-obfs
git submodule update --init
./autogen.sh
./configure \
	--host=${3%-*} \
	--disable-documentation
make
${3}strip src/obfs-local

echo 开始编译 kcptun
cd -
git clone --depth 1 https://github.com/xtaci/kcptun.git
cd kcptun
${6}/bin/go get -u github.com/shadowsocks/kcptun
${6}/bin/go get -u ./...
git clone --depth 1 https://github.com/shadowsocks/kcptun.git
cd kcptun/client
patch -p0 main.go </tmp/main.go.patch
env CC=$8 CXX=$7 GO111MODULE=on CGO_ENABLED=1 GOOS=${9} GOARCH=${10} ${6}/bin/go build -mod=mod -ldflags "-X main.VERSION=$(date -u +%Y%m%d) -s -w" -gcflags "" -o kcptun-plugin

echo 开始编译 v2ray-plugin
cd -
git clone --depth 1 https://github.com/teddysun/v2ray-plugin.git
cd v2ray-plugin
${6}/bin/go get -d -v ./...
env CC=${8} CXX=${7} CGO_ENABLED=1 GOOS=${9} GOARCH=${10} ${6}/bin/go build -v -ldflags "-X main.VERSION=$(date -u +%Y%m%d) -s -w" -gcflags "" -o v2ray-plugin

echo 开始编译 shadowsocks-rust
cd -
git clone --depth 1 https://github.com/shadowsocks/shadowsocks-rust
cd shadowsocks-rust
rustup update
rustc --version
rustup target add ${2}
cargo update --manifest-path Cargo.toml
cross -V 2>/dev/null
[ $? -eq 127 ] && cargo install cross
cross build --release --target ${2} --features "local-http local-http-rustls local-tunnel local-dns local-redir"
${3}strip target/${2}/release/sslocal
cd ${4}/shadowsocks-rust #一定要回到有Makefile文件的目录或者非空目录，不然编译报错。
