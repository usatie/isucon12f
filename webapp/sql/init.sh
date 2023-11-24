#!/bin/sh
set -ex
cd `dirname $0`

ISUCON_DB_HOST=${ISUCON_DB_HOST:-127.0.0.1}
ISUCON_DB_HOST2=${ISUCON_DB_HOST2:-127.0.0.1}
ISUCON_DB_PORT=${ISUCON_DB_PORT:-3306}
ISUCON_DB_USER=${ISUCON_DB_USER:-isucon}
ISUCON_DB_PASSWORD=${ISUCON_DB_PASSWORD:-isucon}
ISUCON_DB_NAME=${ISUCON_DB_NAME:-isucon}

# 
execute_sql_on_two_hosts() {
    local sql_file=$1

    # 第一のホストでSQLファイルを実行
    sudo mysql -u"$ISUCON_DB_USER" \
          -p"$ISUCON_DB_PASSWORD" \
          --host "$ISUCON_DB_HOST" \
          --port "$ISUCON_DB_PORT" \
          "$ISUCON_DB_NAME" < "$sql_file" \
		  --local-infile=1 &
    pid1=$!

    # 第二のホストでSQLファイルを実行
    sudo mysql -u"$ISUCON_DB_USER" \
          -p"$ISUCON_DB_PASSWORD" \
          --host "$ISUCON_DB_HOST2" \
          --port "$ISUCON_DB_PORT" \
          "$ISUCON_DB_NAME" < "$sql_file" \
		  --local-infile=1 &
    pid2=$!

    # 両方のプロセスが終了するのを待つ
    wait $pid1
    local status1=$?
    wait $pid2
    local status2=$?

    # エラーチェック
    if [ $status1 -ne 0 ] || [ $status2 -ne 0 ]; then
        echo "SQL execution failed on one or both hosts."
        return 1
    else
        echo "SQL executed successfully on both hosts."
        return 0
    fi
}

# 3. Schema
execute_sql_on_two_hosts 3_schema_exclude_user_presents.sql

# 4. Data
execute_sql_on_two_hosts 4_alldata_exclude_user_presents.sql

# Delete
echo "delete from user_presents where id > 100000000000" > delete.sql
execute_sql_on_two_hosts delete.sql

# Load
DIR=`mysql -u"$ISUCON_DB_USER" -p"$ISUCON_DB_PASSWORD" -h "$ISUCON_DB_HOST" -Ns -e "show variables like 'secure_file_priv'" | cut -f2`
SECURE_DIR=${DIR:-/var/lib/mysql-files/}
sudo cp 5_user_presents_not_receive_data.tsv ${SECURE_DIR}

echo "LOAD DATA LOCAL INFILE '${SECURE_DIR}5_user_presents_not_receive_data.tsv' REPLACE INTO TABLE user_presents FIELDS ESCAPED BY '|' IGNORE 1 LINES ;" > load.sql

execute_sql_on_two_hosts load.sql
