#!/bin/bash
set -eo pipefail

CONF_FILE="/etc/mysql/my.cnf"

echo "running extended entrypoint"

rm -f $CONF_FILE

echo "[mysqld]" >> $CONF_FILE
echo "pid-file        = /var/run/mysqld/mysqld.pid" >> $CONF_FILE
echo "socket          = /var/run/mysqld/mysqld.sock" >> $CONF_FILE
echo "datadir         = /var/lib/mysql" >> $CONF_FILE
echo "secure-file-priv= NULL" >> $CONF_FILE

echo "# Custom config should go here" >> $CONF_FILE
echo "!includedir /etc/mysql/conf.d/" >> $CONF_FILE

while IFS='=' read -r envvar_key envvar_value
do
    if [[ "$envvar_key" =~ ^conf\..+ ]]; then
        if [[ ! -z $envvar_value ]]; then
            config_key=${envvar_key#*conf.}
            if [[ $config_key == "skip-host-cache" ]]; then
                echo "skip-host-cache" >> $CONF_FILE
            elif [[ $config_key == "skip-name-resolve" ]]; then
                echo "skip-name-resolve" >> $CONF_FILE
            else
                echo "$config_key        = $envvar_value" >> $CONF_FILE
            fi

        fi
    fi
done < <(env)

#https://github.com/gritt/docker-mysql-replication/tree/topology/master-master/docker/database/config
create_replication_user () {
  sleep 10
  echo "creating replication user $1"
  mysql --host localhost -uroot -p$MYSQL_ROOT_PASSWORD -AN -e "CREATE USER '$1'@'%' IDENTIFIED BY '$MYSQL_REPLICATION_PASSWORD';"
  mysql --host localhost -uroot -p$MYSQL_ROOT_PASSWORD -AN -e "GRANT REPLICATION SLAVE ON *.* TO '$1'@'%';"
  mysql --host localhost -uroot -p$MYSQL_ROOT_PASSWORD -AN -e "FLUSH PRIVILEGES;"
}


echo "using the following config"
cat $CONF_FILE

if [ -n "$MYSQL_REPLICATION_USER" ]; then
    echo "going to create replication user"
   create_replication_user $MYSQL_REPLICATION_USER &
fi

exec /usr/local/bin/docker-entrypoint.sh "$@"

