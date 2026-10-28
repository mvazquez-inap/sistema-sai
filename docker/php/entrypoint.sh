#!/bin/sh
# Forward the application's localhost MySQL port to the disposable MariaDB 11.
# mysqlnd reaches "localhost" over TCP. Do not change the connection charset.
set -eu

if [ -n "${SAI_DB_UPSTREAM:-}" ]; then
    mkdir -p /var/run/mysqld
    rm -f /var/run/mysqld/mysqld.sock
    socat UNIX-LISTEN:/var/run/mysqld/mysqld.sock,fork,reuseaddr,mode=777 "TCP:${SAI_DB_UPSTREAM}" &
fi

exec docker-php-entrypoint "$@"
