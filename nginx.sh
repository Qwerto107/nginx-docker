#!/bin/sh

openssl_version="3.5.4"
nginx_version="1.29.4"

check_status() {
    if [ $? -eq 0 ]; then
        echo "$1 executed successfully"
    else
        echo "$1 failed"
        exit 1
    fi
}
# 安装依赖
install_dependencies() {
    apt update
	apt install make cmake gcc g++ git libz-dev bzip2 libzstd-dev -y
    check_status "Dependencies installation"
}

# 下载 nginx 源码
download_nginx() {
    wget "https://nginx.org/download/nginx-${nginx_version}.tar.gz"
    tar zxvf nginx-${nginx_version}.tar.gz
    check_status "Nginx source code download"
}

# 下载 openssl 源码
download_openssl() {
    wget "https://www.openssl.org/source/openssl-${openssl_version}.tar.gz"
    tar zxvf "openssl-${openssl_version}.tar.gz"
    check_status "OpenSSL source code download"
}

# 下载 pcre 源码
download_pcre() {
    wget https://ftp.exim.org/pub/pcre/pcre-8.45.tar.gz
    tar -zxvf pcre-8.45.tar.gz
    check_status "PCRE source code download"
}

# 下载 zlib-cf 源码
download_zlib_cf() {
    git clone https://github.com/cloudflare/zlib.git zlib-cf
    cd zlib-cf
    make -f Makefile.in distclean
    cd ..
    check_status "zlib-cf source code download"
}

# 下载 ngx_brotli 源码
download_and_make_brotli() {
    git clone https://github.com/google/ngx_brotli
    cd ngx_brotli
    git submodule update --init --recursive
    mkdir deps/brotli/out && cd deps/brotli/out
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -mtune=generic -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..
    cmake --build . --config Release --target brotlienc
    cd ../../../..
    export CFLAGS="-m64 -mtune=generic -Ofast -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections"
    export LDFLAGS="-m64 -Wl,-s -Wl,-Bsymbolic -Wl,--gc-sections"
    check_status "ngx_brotli source code download and make"
}

# 下载 headers-more-nginx-module 源码
download_headers_more_module() {
    git clone https://github.com/openresty/headers-more-nginx-module.git
    check_status "headers-more-nginx-module source code download"
}

# 打补丁
apply_patches() {
    curl https://raw.githubusercontent.com/Qwerto107/nginx-patch/main/error_page.patch | patch -p1
    cd ..
    check_status "Patches applied"
}

# 编译和安装 Nginx
compile_and_install_nginx() {
    cd nginx-${nginx_version}/
    ./configure --user=www --group=www --prefix=/usr/local/nginx --with-openssl=../openssl-${openssl_version} --with-openssl-opt='zlib -mtune=generic -Wl,-flto' --with-http_ssl_module --with-http_v2_module --with-http_sub_module --with-http_gzip_static_module --with-http_stub_status_module --with-zlib=../zlib-cf --with-pcre=../pcre-8.45 --with-pcre-jit --add-module=../ngx_brotli --add-module=../headers-more-nginx-module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-http_v3_module --with-ld-opt='-Wl,-z,relro -Wl,-z,now -fPIC -lrt' --with-cc-opt='-mtune=generic'
    make -j$(cat /proc/cpuinfo | grep "processor" | wc -l)
    make install
    check_status "Nginx compilation and installation"
}


main() {
    install_dependencies
    download_nginx
    download_openssl
    download_pcre
    download_zlib_cf
    download_and_make_brotli
    download_nginx_ct
    download_headers_more_module
    apply_patches
    compile_and_install_nginx
}
main
