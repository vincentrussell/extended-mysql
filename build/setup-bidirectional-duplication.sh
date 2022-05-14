#!/bin/bash
set -eo pipefail

#based on https://github.com/gritt/docker-mysql-replication/tree/topology/master-master/docker/database/config

if [[ -z "$SERVER_1" ]]; then
   echo "missing variable SERVER_1"
   exit 1
fi

if [[ -z "$SERVER_2" ]]; then
   echo "missing variable SERVER_2"
   exit 1
fi

if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
   echo "missing variable MYSQL_ROOT_PASSWORD"
   exit 1
fi

if [[ -z "$MYSQL_REPLICATION_USER" ]]; then
   echo "missing variable MYSQL_REPLICATION_USER"
   exit 1
fi

if [[ -z "$MYSQL_REPLICATION_PASSWORD" ]]; then
   echo "missing variable MYSQL_REPLICATION_PASSWORD"
   exit 1
fi

echo "waiting before running script to setup bidrectional duplication.."
sleep 30

CONNECTION_ARGS="-uroot -p$MYSQL_ROOT_PASSWORD --ssl-ca=$SSL_CA --ssl-cert=$SSL_CERT --ssl-key=$SSL_KEY"
CHANGE_MASTER_OPTIONS=""

if [[ -n "$SSL_CERT" ]]; then
CONNECTION_ARGS="$CONNECTION_ARGS "
CHANGE_MASTER_OPTIONS=",MASTER_SSL=1,MASTER_SSL_CA='$SSL_CA',MASTER_SSL_CERT='$SSL_CERT',MASTER_SSL_KEY='$SSL_KEY'"
  if [[ -n "$TLS_VERSION" ]]; then
      CHANGE_MASTER_OPTIONS="$CHANGE_MASTER_OPTIONS,MASTER_TLS_VERSION='$MASTER_TLS_VERSION'"
  fi

  if [[ -n "$TLS_CIPHERSUITES" ]]; then
      CHANGE_MASTER_OPTIONS="$CHANGE_MASTER_OPTIONS,MASTER_TLS_CIPHERSUITES='$TLS_CIPHERSUITES'"
  fi
fi


echo "stopping slave in $SERVER_2"
mysql --host $SERVER_2 $CONNECTION_ARGS -AN -e "stop slave;";
mysql --host $SERVER_2 $CONNECTION_ARGS -AN -e "reset slave all;";

echo "stopping slave in $SERVER_1"
mysql --host $SERVER_1 $CONNECTION_ARGS -AN -e "stop slave;";
mysql --host $SERVER_1 $CONNECTION_ARGS -AN -e "reset slave all;";

echo "creating $MYSQL_REPLICATION_USER on $SERVER_1"
mysql --host $SERVER_1 $CONNECTION_ARGS -AN -e "CREATE USER '$MYSQL_REPLICATION_USER'@'%' IDENTIFIED BY '$MYSQL_REPLICATION_PASSWORD';"
mysql --host $SERVER_1 $CONNECTION_ARGS -AN -e "GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_REPLICATION_USER'@'%';"
mysql --host $SERVER_1 $CONNECTION_ARGS -AN -e "FLUSH PRIVILEGES;"

echo "creating $MYSQL_REPLICATION_USER on $SERVER_2"
mysql --host $SERVER_2 $CONNECTION_ARGS -AN -e "CREATE USER '$MYSQL_REPLICATION_USER'@'%' IDENTIFIED BY '$MYSQL_REPLICATION_PASSWORD';"
mysql --host $SERVER_2 $CONNECTION_ARGS -AN -e "GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_REPLICATION_USER'@'%';"
mysql --host $SERVER_2 $CONNECTION_ARGS -AN -e "FLUSH PRIVILEGES;"

echo "getting SERVER_1 MYSQL config"
SERVER_1_POSITION="$(mysql --host $SERVER_1 $CONNECTION_ARGS -e 'show master status \G' | grep Position | grep -o '[0-9]*')"
SERVER_1_FILE="$(mysql --host $SERVER_1 $CONNECTION_ARGS -e 'show master status \G' | grep File | sed -n -e 's/^.*: //p')"

echo "getting SERVER_2 MYSQL config"
SERVER_2_POSITION="$(mysql --host $SERVER_2 $CONNECTION_ARGS -e 'show master status \G' | grep Position | grep -o '[0-9]*')"
SERVER_2_FILE="$(mysql --host $SERVER_2 $CONNECTION_ARGS -e 'show master status \G' | grep File | sed -n -e 's/^.*: //p')"

echo "set SERVER_2 to upstream SERVER_1"
mysql --host $SERVER_2 $CONNECTION_ARGS -AN -e "change master to master_host='$SERVER_1',master_user='$MYSQL_REPLICATION_USER',master_password='$MYSQL_REPLICATION_PASSWORD',master_log_file='$SERVER_1_FILE',master_log_pos=${SERVER_1_POSITION}${CHANGE_MASTER_OPTIONS};"

echo "set SERVER_1 to upstream SERVER_2"
mysql --host $SERVER_1 $CONNECTION_ARGS -AN -e"change master to master_host='$SERVER_2',master_user='$MYSQL_REPLICATION_USER',master_password='$MYSQL_REPLICATION_PASSWORD',master_log_file='$SERVER_2_FILE',master_log_pos=${SERVER_2_POSITION}${CHANGE_MASTER_OPTIONS};"

echo "start sync: SERVER_1 to SERVER_2"
mysql --host $SERVER_1 $CONNECTION_ARGS -AN -e "start slave;"
mysql --host $SERVER_1 $CONNECTION_ARGS -e "show slave status \G;"


echo "start sync: SERVER_2 to SERVER_1"
mysql --host $SERVER_2 $CONNECTION_ARGS -AN -e "start slave;"
mysql --host $SERVER_2 $CONNECTION_ARGS -e "show slave status \G;"


echo "mysql fine tuning and extra conf"

echo "increasing connection limit"
mysql --host $SERVER_1 $CONNECTION_ARGS -AN -e "set GLOBAL max_connections=2000;"
mysql --host $SERVER_2 $CONNECTION_ARGS -AN -e "set GLOBAL max_connections=2000;"


echo "disabling sql_mode = ONLY_FULL_GROUP_BY"
mysql --host $SERVER_1 $CONNECTION_ARGS -AN -e "SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));"
mysql --host $SERVER_2 $CONNECTION_ARGS -AN -e "SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));"

exit 0