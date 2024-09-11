#!/bin/bash

TABLET_UID=$1
export VTDATAROOT="$2"

MYSQL_PORT=$[17000 + $TABLET_UID]

mkdir -p $VTDATAROOT/backups
mkdir -p $VTDATAROOT/logs

/usr/local/vitess/bin/mysqlctl \
 --log_dir $VTDATAROOT/logs \
 --tablet_uid $TABLET_UID \
 --tablet_dir tablet \
 --mysql_port $MYSQL_PORT \
 --mysql_socket $VTDATAROOT/mysql.sock \
 init

/usr/local/vitess/bin/mysqlctl --tablet_uid $TABLET_UID --tablet_dir tablet shutdown

sed -i "s+pid-file[^\n]*+pid-file = $3+" $VTDATAROOT/tablet/my.cnf

echo "Initialized MySQL for tablet $TABLET_UID..."
