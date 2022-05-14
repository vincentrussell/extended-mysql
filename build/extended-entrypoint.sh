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

echo "using the following config"
cat $CONF_FILE

if [ "$MODE" == "setup_duplication" ]; then
    exec /usr/local/bin/setup-bidirectional-duplication.sh "$@"
    exit 0
else   
    exec /usr/local/bin/docker-entrypoint.sh "$@"
fi

