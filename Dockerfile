FROM debian:bookworm AS BUILD

ARG PHP_VERSION=5.4.16
# production or development
ARG PHP_ENV=production

# dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        wget \
        build-essential \
        ca-certificates \
        apache2 \
        apache2-dev \
        libbz2-dev \
        freetds-dev \
        libcurl4-gnutls-dev \
        libgmp3-dev \
        libmhash-dev \
        libpq-dev \
        libsasl2-dev \
        libxml2-dev \
        libxslt1-dev \
        libzip-dev \
        libgd-dev \
        sendmail \
        byacc \
        file \
        re2c && \  
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp



# https://www.veritech.net/compiling-apache-mysql-php-source/
# libtool --finish warning
# https://stackoverflow.com/questions/32766609/libtool-installation-issue-with-make-install
# TODO: Check freetype
# DEPRECATED: Not using openssl (PHP too old)
ENV LDFLAGS="-Wl,--copy-dt-needed-entries"

RUN ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h && \
    ln -s /usr/lib/x86_64-linux-gnu/libsybdb.so /usr/lib/libsybdb.so && \
    ln -s /usr/lib/x86_64-linux-gnu/libldap.so /usr/lib/libldap.so && \
    ln -s /usr/lib/x86_64-linux-gnu/libXpm.so /usr/lib/libXpm.so && \
    mkdir /usr/include/curl && \
    ln -s /usr/include/x86_64-linux-gnu/curl/easy.h /usr/include/curl/easy.h && \  
    wget -O- http://museum.php.net/php5/php-${PHP_VERSION}.tar.gz | tar zx && \
    ( \
        cd php-${PHP_VERSION} && \
        ./configure \
            --prefix=/usr/local \
            --mandir=/tmp \
            --with-apxs2=/usr/bin/apxs \
            --disable-cgi \
            --with-gnu-ld \
            --with-bz2 \
            --with-curl \
            --with-gd \
            --with-gettext \
            --with-gmp \
            --with-ldap \
            --with-ldap-sasl \
            --with-mhash \
            --with-mssql \
            --with-pdo-dblib \
            --with-pdo-pgsql \
            --with-pgsql \
            --with-xsl \
            --with-zlib \
            --with-jpeg-dir=/usr/lib/x86_64-linux-gnu \
            --with-xpm-dir=/usr \
            --enable-bcmath \
            --enable-calendar \
            --enable-exif \
            --enable-ftp \
            --enable-mbstring \
            --enable-shmop \
            --enable-sockets \
            --enable-wddx \
            --enable-zip && \
        make && \      
        make install && \
        cp php.ini-${PHP_ENV} /usr/local/lib/php.ini && \
        sed -i 's/;date.timezone =.*/  date.timezone \= "America\/Sao_Paulo"/' /usr/local/lib/php.ini \
    )

RUN echo "AddHandler application/x-httpd-php .php" > /etc/apache2/mods-available/php5.conf && \
    echo "AddType application/x-httpd-php .php" >> /etc/apache2/mods-available/php5.conf && \
    echo "AddType application/x-httpd-php-source .phps" >> /etc/apache2/mods-available/php5.conf && \
    sed -i '13i \\tDirectoryIndex index.php index.html' /etc/apache2/sites-available/000-default.conf && \
    a2dismod mpm_event mpm_worker php5 && \
    a2enmod mpm_prefork php5 && \
    wget -O /var/www/html/favicon.ico https://www.php.net/images/logos/php.ico && \
    echo "<?php phpinfo(); ?>" > /var/www/html/index.php


FROM debian:bookworm-slim AS RELEASE

# dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        ca-certificates \
        apache2 \
        libcurl3-gnutls \
        libgd3 \
        libpq5 \
        libsybdb5 \
        libxml2 \
        libxslt1.1 \
        sendmail && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

COPY --from=BUILD /usr/local /usr/local
COPY --from=BUILD /usr/lib/apache2/modules/libphp5.so /usr/lib/apache2/modules
COPY --from=BUILD /etc/apache2/mods-available/php5.* /etc/apache2/mods-available
COPY --from=BUILD /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available
COPY --from=BUILD /var/www/html /var/www/html

RUN a2dismod mpm_event mpm_worker php5 && \
    a2enmod mpm_prefork php5

WORKDIR /var/www/html

# EXPOSE 8080

CMD [ "apache2ctl", "-D", "FOREGROUND" ]
