#!/bin/sh
# mysqlnd opens a socket when the host is localhost. Forward that socket to
# SAI_DB_UPSTREAM. Any other SAI_DB_HOST is used unchanged.
# Do not change the connection charset.
set -eu

db_host="${SAI_DB_HOST:-}"
if [ "$db_host" = "localhost" ] && [ -n "${SAI_DB_UPSTREAM:-}" ]; then
    mkdir -p /var/run/mysqld
    rm -f /var/run/mysqld/mysqld.sock
    socat UNIX-LISTEN:/var/run/mysqld/mysqld.sock,fork,reuseaddr,mode=777 "TCP:${SAI_DB_UPSTREAM}" &
fi

exec docker-php-entrypoint "$@"
