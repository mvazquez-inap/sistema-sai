FROM php:8.4-fpm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libcurl4-openssl-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libonig-dev \
        libpng-dev \
        libxml2-dev \
        libzip-dev \
        socat \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        curl \
        gd \
        mbstring \
        mysqli \
        pdo_mysql \
        soap \
        zip \
    && docker-php-ext-enable opcache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/sai \
    && chown -R www-data:www-data /var/www/sai

COPY ./docker/php/conf.d/sai.ini /usr/local/etc/php/conf.d/sai.ini
COPY ./docker/php/zz-sai.conf /usr/local/etc/php-fpm.d/zz-sai.conf
COPY ./docker/php/entrypoint.sh /usr/local/bin/sai-entrypoint
RUN chmod +x /usr/local/bin/sai-entrypoint

ENTRYPOINT ["sai-entrypoint"]
CMD ["php-fpm"]

WORKDIR /var/www/sai
