FROM nginx:stable-alpine
ADD ./docker/nginx/default.conf /etc/nginx/conf.d/default.conf
RUN mkdir -p /var/www/sai
RUN chown -R nginx:nginx /var/www/sai

# https://hub.docker.com/r/andthensome/docker-php-5.3-fpm
# 
FROM andthensome/docker-php-5.3-fpm
# https://hub.docker.com/r/cespi/php-5.3/
#
# FROM cespi/php-5.3:modules-fpm
# FROM yannickvh/php:5.3-fpm
# https://www.zend.com/blog/php-docker-images-tips-tricks
RUN mkdir -p /var/www/sai
RUN chown -R www-data:www-data /var/www/sai
ADD ./docker/php/php.ini /usr/local/etc/php/php.ini
ADD ./docker/php/php-fpm.conf /usr/local/etc/php-fpm.conf
WORKDIR /var/www/sai
