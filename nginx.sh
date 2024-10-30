#!/bin/sh

check_status() {
    if [ $? -eq 0 ]; then
        echo "$1 executed successfully"
    else
        echo "$1 failed"
        exit 1
    fi
}

# 设置时区
set_timezone() {
    apk add --no-cache ca-certificates
    apk add --no-cache tzdata
    cp -rf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    check_status "Set timezone"
}

# 工作目录
setup_workdir() {
    mkdir -p /tmp/nginx && cd /tmp/nginx
    check_status "Workdir setup"
}

# 更新软件包列表
update_packages() {
    apk update
    check_status "Package list update"
}

# 安装依赖
install_dependencies() {
    apk add --no-cache make cmake gcc g++ git zlib zlib-dev libc-dev pcre-dev perl linux-headers patch curl
    check_status "Dependencies installation"
    cat /proc/cpuinfo
}

# 下载 nginx 源码
download_nginx() {
    wget https://nginx.org/download/nginx-1.27.2.tar.gz
    tar zxvf nginx-1.27.2.tar.gz
    check_status "Nginx source code download"
}

# 下载 openssl 源码
download_openssl() {
    wget https://www.openssl.org/source/openssl-1.1.1w.tar.gz
    tar zxvf openssl-1.1.1w.tar.gz
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

# 下载 ngx_http_geoip2_module 源码
download_geoip2_and_install_libmaxminddb() {
    git clone https://github.com/leev/ngx_http_geoip2_module.git
    check_status "ngx_http_geoip2_module source code download"

    wget https://github.com/maxmind/libmaxminddb/releases/download/1.8.0/libmaxminddb-1.8.0.tar.gz && \
    tar zxvf libmaxminddb-1.8.0.tar.gz && \
    cd libmaxminddb-1.8.0 && \
    ./configure && make && make install && \
    echo /usr/local/lib >> /etc/ld.so.conf && \
    ldconfig /etc/ld.so.conf  && \
    cd ..
    check_status "libmaxminddb source code download"
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

# 下载 jemalloc 源码
download_and_makeinstall_jemalloc() {
    wget https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2
    tar -jxvf jemalloc-5.3.0.tar.bz2
    cd jemalloc-5.3.0/
    ./configure -prefix=/usr/local/jemalloc --libdir=/usr/local/lib
    make -j$(cat /proc/cpuinfo | grep "processor" | wc -l)
    make install
    echo /usr/local/lib >> /etc/ld.so.conf
    ldconfig
    cd ../
    check_status "jemalloc source code download"
}

# 打补丁
apply_patches() {
    cd openssl-1.1.1w/
    curl https://raw.githubusercontent.com/kn007/patch/master/openssl-1.1.1.patch | patch -p1
    cd ..

    cd nginx-1.27.2/
    curl https://raw.githubusercontent.com/kn007/patch/master/nginx_dynamic_tls_records.patch | patch -p1
    curl https://raw.githubusercontent.com/Qwerto107/nginx-patch/main/error_page.patch | patch -p1
    cd ..
    check_status "Patches applied"
}

# 编译和安装 Nginx
compile_and_install_nginx() {
    cd nginx-1.27.2/
    ./configure --user=www --group=www --prefix=/usr/local/nginx --with-openssl=../openssl-1.1.1w --with-openssl-opt='zlib -mtune=generic -ljemalloc -Wl,-flto' --with-http_ssl_module --with-http_v2_module --with-http_sub_module --with-http_gzip_static_module --with-http_stub_status_module --with-zlib=../zlib-cf --with-pcre=../pcre-8.45 --with-pcre-jit --add-module=../ngx_brotli --add-module=../headers-more-nginx-module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-http_v3_module --add-module=../ngx_http_geoip2_module --with-ld-opt='-Wl,-z,relro -Wl,-z,now -fPIC -ljemalloc -lrt' --with-cc-opt='-mtune=generic'
    make -j$(cat /proc/cpuinfo | grep "processor" | wc -l)
    make install
    check_status "Nginx compilation and installation"
}

# 清理环境
cleanup() {
    apk del make cmake git zlib-dev curl linux-headers
    rm -rf /tmp/nginx
    check_status "Environment cleanup"
}

# 创建用户和组
create_user_and_group() {
    addgroup -S www && adduser -S www -G www
    mkdir /home/wwwroot && mkdir /home/wwwlogs
    chown www:www /home/www* -R
    chown www:www /usr/local/nginx -R
    check_status "User and group creation"
}


main() {
    setup_workdir
    set_timezone
    update_packages
    install_dependencies
    download_nginx
    download_openssl
    download_pcre
    download_zlib_cf
    download_geoip2_module
    download_and_make_brotli
    download_nginx_ct
    download_headers_more_module
    download_geoip2_and_install_libmaxminddb
    download_and_makeinstall_jemalloc
    apply_patches
    compile_and_install_nginx
    cleanup
    create_user_and_group
}


main
