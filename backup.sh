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
dump ${dump_level}f ${DUMP_DIR}/dump-${dump_level}-${date_stamp}.dump / &> $log_file
if [ "$?" -ne "0" ]
  then errors=1
fi

# backup postgres
su -c "pg_dumpall -f ${POSTGRES_DUMP_DIR}/postgres-${date_stamp}.dump" ${POSTGRES_USER} &>>$log_file
if [ "$?" -ne "0" ]
  then errors=1
fi

echo "Removing old dumps" >> $log_file
find $DUMP_DIR -mtime +7 -regex ".+/dump-[1-7]-.+" -print -exec rm {} \; >> $log_file

# TODO keep one level 0 dump from each month

# TODO remove old postgres dumps

if [ "$errors" -ne "0" ]
then
  mail_file=/tmp/backup.mail.$$
  echo "Subject: backup errors" > $mail_file
  echo >> $mail_file
  cat $log_file >> $mail_file
  sendmail $EMAIL < $mail_file
fi
