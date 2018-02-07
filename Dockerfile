# gokaygurcan/test

# base image
FROM ubuntu:xenial

# version
LABEL version="0.1.2"

# maintainer
LABEL maintainer="Gökay Gürcan <info@gokaygurcan.com>"

# arguments
ARG ARCH=x64
ARG AMPLIFY_KEY
ARG WEBSITE=www.example.com

# variables
ENV NGINX_SRC /usr/src/nginx
ENV GEOIP_SRC /usr/local/share/GeoIP
ENV NGINX_VERSION 1.13.8
ENV OPENSSL_VERSION 1.0.2n
ENV NJS_VERSION 0.1.15
ENV PAGESPEED_VERSION 1.13.35.2
ENV PAGESPEED_RELEASE stable
ENV HEADERS_MORE_VERSION 0.33
ENV CACHE_PURGE_VERSION 2.3

# prepare the image
RUN apt-get update -q && \
    apt-get upgrade -y && \
    apt-get install -y apt-utils aria2 build-essential gzip libpcre3 libpcre3-dev perl unzip uuid-dev wget zlibc zlib1g zlib1g-dev 

# source directory
RUN mkdir -p ${NGINX_SRC} && \
    mkdir -p ${GEOIP_SRC}

# download geoip
WORKDIR ${NGINX_SRC}
RUN wget http://geolite.maxmind.com/download/geoip/api/c/GeoIP.tar.gz && \
    tar -zxvf GeoIP.tar.gz && \
    rm GeoIP.tar.gz && \
    mv GeoIP-* GeoIP

# compile geoip
WORKDIR ${NGINX_SRC}/GeoIP
RUN ./configure && \
    make && \
    make install && \
    echo '/usr/local/lib' | tee -a /etc/ld.so.conf.d/geoip.conf && \
    ldconfig

# download nginx
WORKDIR ${NGINX_SRC}
RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -xzvf ${NGINX_SRC}/nginx-${NGINX_VERSION}.tar.gz && \
    rm nginx-${NGINX_VERSION}.tar.gz

# create modules directory
WORKDIR ${NGINX_SRC}/nginx-${NGINX_VERSION}
RUN mkdir -p ${NGINX_SRC}/modules

# download openssl
WORKDIR ${NGINX_SRC}/nginx-${NGINX_VERSION}/modules
RUN wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar -xzvf openssl-${OPENSSL_VERSION}.tar.gz && \
    rm openssl-${OPENSSL_VERSION}.tar.gz

# download njx
WORKDIR ${NGINX_SRC}/nginx-${NGINX_VERSION}/modules
RUN aria2c https://github.com/nginx/njs/archive/${NJS_VERSION}.tar.gz && \
    tar -xzvf njs-${NJS_VERSION}.tar.gz && \
    rm njs-${NJS_VERSION}.tar.gz

# download pagespeed
WORKDIR ${NGINX_SRC}/nginx-${NGINX_VERSION}/modules
RUN wget https://github.com/apache/incubator-pagespeed-ngx/archive/v${PAGESPEED_VERSION}-${PAGESPEED_RELEASE}.tar.gz && \
    tar -xzvf v${PAGESPEED_VERSION}-${PAGESPEED_RELEASE}.tar.gz && \
    rm v${PAGESPEED_VERSION}-${PAGESPEED_RELEASE}.tar.gz

# download psol for pagespeed
WORKDIR ${NGINX_SRC}/nginx-${NGINX_VERSION}/modules/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-${PAGESPEED_RELEASE}
RUN wget https://dl.google.com/dl/page-speed/psol/${PAGESPEED_VERSION}-${ARCH}.tar.gz && \
    tar -xzvf ${PAGESPEED_VERSION}-${ARCH}.tar.gz && \
    rm ${PAGESPEED_VERSION}-${ARCH}.tar.gz

# download headers-more-nginx-module
WORKDIR ${NGINX_SRC}/nginx-${NGINX_VERSION}/modules
RUN aria2c https://github.com/openresty/headers-more-nginx-module/archive/v${HEADERS_MORE_VERSION}.tar.gz && \
    tar -xzvf headers-more-nginx-module-${HEADERS_MORE_VERSION}.tar.gz && \
    rm headers-more-nginx-module-${HEADERS_MORE_VERSION}.tar.gz

# download ngx cache purge module
WORKDIR ${NGINX_SRC}/nginx-${NGINX_VERSION}/modules
RUN aria2c https://github.com/FRiCKLE/ngx_cache_purge/archive/${CACHE_PURGE_VERSION}.tar.gz && \
    tar -xzvf ngx_cache_purge-${CACHE_PURGE_VERSION}.tar.gz && \
    rm ngx_cache_purge-${CACHE_PURGE_VERSION}.tar.gz

# download testcookie module
WORKDIR ${NGINX_SRC}/nginx-${NGINX_VERSION}/modules
RUN aria2c https://github.com/kyprizel/testcookie-nginx-module/tarball/master && \
    tar -xzvf kyprizel-testcookie-nginx-module-*.tar.gz && \
    rm kyprizel-testcookie-nginx-module-*.tar.gz && \
    mv kyprizel-testcookie-nginx-module-* kyprizel-testcookie-nginx-module

# download sysguard
WORKDIR ${NGINX_SRC}/nginx-${NGINX_VERSION}/modules
RUN aria2c https://github.com/vozlt/nginx-module-sysguard/tarball/master && \
    tar -xzvf vozlt-nginx-module-sysguard-*.tar.gz && \
    rm vozlt-nginx-module-sysguard-*.tar.gz && \
    mv vozlt-nginx-module-sysguard-* vozlt-nginx-module-sysguard

# download geoip databases
WORKDIR ${GEOIP_SRC}
RUN rm -rf ./* && \
    wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz && \
    gzip -d GeoIP.dat.gz && \
    wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz && \
    gzip -d GeoLiteCity.dat.gz

# build nginx
WORKDIR ${NGINX_SRC}/nginx-${NGINX_VERSION}
RUN ./configure \
    --conf-path=/etc/nginx/nginx.conf \
    --sbin-path=/usr/sbin/nginx \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --with-http_addition_module \    
#   --with-debug \ # --with-debug and PSOL are not compatible
    --with-file-aio \    
    --with-http_geoip_module \
    --with-http_gzip_static_module \
    --with-http_realip_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-openssl=./modules/openssl-${OPENSSL_VERSION} \
    --add-module=${NGINX_SRC}/nginx-${NGINX_VERSION}/modules/njs-${NJS_VERSION}/nginx \
    --add-module=${NGINX_SRC}/nginx-${NGINX_VERSION}/modules/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-${PAGESPEED_RELEASE} \
    --add-module=${NGINX_SRC}/nginx-${NGINX_VERSION}/modules/headers-more-nginx-module-${HEADERS_MORE_VERSION} \
    --add-module=${NGINX_SRC}/nginx-${NGINX_VERSION}/modules/ngx_cache_purge-${CACHE_PURGE_VERSION} \
    --add-module=${NGINX_SRC}/nginx-${NGINX_VERSION}/modules/kyprizel-testcookie-nginx-module \
    --add-module=${NGINX_SRC}/nginx-${NGINX_VERSION}/modules/vozlt-nginx-module-sysguard && \
    make && \
    make install

# download and install amplify
WORKDIR ${NGINX_SRC}/nginx-${NGINX_VERSION}
RUN if [ -z "${AMPLIFY_KEY}" ]; then \
         wget https://github.com/nginxinc/nginx-amplify-agent/raw/master/packages/install.sh && \
         chmod +x install.sh && \
         API_KEY='${AMPLIFY_KEY}' sh ./install.sh && \
         echo "https://amplify.nginx.com/"; \
    fi

# other settings
EXPOSE 80

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
