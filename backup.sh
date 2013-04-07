#!/bin/bash

DUMP_DIR="/backups"
# the postgres dump dir must be writable by the postgres user
POSTGRES_DUMP_DIR="/backups/postgres"
POSTGRES_USER="postgres"
EMAIL="alwold@gmail.com"

dump_level=`date +%w`
date_stamp=`date +%Y%m%d`
log_file=${DUMP_DIR}/backup.log.${date_stamp}
errors=0

# TODO check if dump volume is mounted?

# backup the root partition
/sbin/dump ${dump_level}uf ${DUMP_DIR}/dump-${dump_level}-${date_stamp}.dump / &> $log_file
if [ "$?" -ne "0" ]
  then errors=1
fi

# backup postgres
mkdir -p $POSTGRES_DUMP_DIR
chown $POSTGRES_USER $POSTGRES_DUMP_DIR
cd $POSTGRES_DUMP_DIR
su -c "pg_dumpall -f ${POSTGRES_DUMP_DIR}/postgres-${date_stamp}.dump" ${POSTGRES_USER} &>>$log_file
if [ "$?" -ne "0" ]
  then errors=1
fi

echo "Removing old dumps" >> $log_file
# remove anything older than 7 days that isn't level 0
find $DUMP_DIR -mtime +7 -regex ".+/dump-[1-7]-.+" -print -exec rm {} \; >> $log_file

# TODO keep one level 0 dump from each month

# remove postgres dumps older than 10 days
# TODO keep like one from each week for the last month
find $POSTGRES_DUMP_DIR -mtime +10 -print -exec rm {} \; >> $log_file

if [ "$errors" -ne "0" ]
then
  mail_file=/tmp/backup.mail.$$
  echo "Subject: backup errors" > $mail_file
  echo >> $mail_file
  cat $log_file >> $mail_file
  /usr/sbin/sendmail $EMAIL < $mail_file
fi
