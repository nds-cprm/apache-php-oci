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
        libxml2-dev \
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
RUN wget -O- http://museum.php.net/php5/php-${PHP_VERSION}.tar.gz | tar zx && \
    ( \
        cd php-${PHP_VERSION} && \
        ./configure \
            --prefix=/usr/local \
            --with-apxs2=/usr/bin/apxs \
            --disable-cgi \
            --with-gnu-ld && \
        make && \      
        make install && \
        cp php.ini-${PHP_ENV} /usr/local/lib/php.ini && \
        sed -i 's/;date.timezone =.*/  date.timezone \= "America\/Sao_Paulo"/' /usr/local/lib/php.ini \
    )

FROM debian:bookworm-slim AS RELEASE

# dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        ca-certificates \
        apache2 \
        libxml2 \
        sendmail && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

COPY --from=BUILD /usr/lib/apache2/modules/libphp5.so /usr/lib/apache2/modules
COPY --from=BUILD /etc/apache2/mods-available/php5.load /etc/apache2/mods-available
COPY --from=BUILD /usr/local /usr/local

RUN a2dismod mpm_event mpm_worker php5 && \
    echo "AddHandler application/x-httpd-php .php" > /etc/apache2/mods-available/php5.conf && \
    echo "AddType application/x-httpd-php .php" >> /etc/apache2/mods-available/php5.conf && \
    echo "AddType application/x-httpd-php-source .phps" >> /etc/apache2/mods-available/php5.conf && \
    sed -i '13i \\tDirectoryIndex index.php index.html' /etc/apache2/sites-available/000-default.conf && \
    a2enmod mpm_prefork php5 && \
    echo "<?php phpinfo(); ?>" > /var/www/html/index.php

WORKDIR /var/www/html

# EXPOSE 8080

CMD [ "apache2ctl", "-D", "FOREGROUND" ]
