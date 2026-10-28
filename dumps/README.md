# Load the utf8mb4 SAI copy on Galera

`dumps/sai-utf8mb4.sql.gz` is a MariaDB 11 dump of `sai`, `tabgralessai`, and `tabgrales2` after the utf8mb4 conversion. Git does not store that file. Copy it to a host that can reach `192.168.70.139` before loading.

## Load

Load it on one Galera node. The dump creates those three databases when they are missing and replaces the tables inside them.

```sh
gzip -dc dumps/sai-utf8mb4.sql.gz | mariadb --host=192.168.70.139 --port=3306 --user=root -p
```

Use another port only when the node is not listening on 3306.

## User sai_pre

Create `sai_pre` after the databases exist. The password is the value of `SAI_DB_PASSWORD` in the local `.env`. That file is gitignored. Do not copy the password into this README or into a commit.

```sql
CREATE USER 'sai_pre'@'%' IDENTIFIED BY '<SAI_DB_PASSWORD from the local .env>';
GRANT ALL PRIVILEGES ON `sai`.* TO 'sai_pre'@'%';
GRANT ALL PRIVILEGES ON `tabgralessai`.* TO 'sai_pre'@'%';
GRANT ALL PRIVILEGES ON `tabgrales2`.* TO 'sai_pre'@'%';
FLUSH PRIVILEGES;
```

On the application host, set `SAI_DB_HOST` to `192.168.70.139`, `SAI_DB_USER` to `sai_pre`, and `SAI_DB_PASSWORD` to that same local `.env` value. The PHP entrypoint forwards a host of `localhost` to `SAI_DB_UPSTREAM` and leaves `192.168.70.139` unchanged.
