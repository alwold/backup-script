#!/bin/bash

DUMP_DIR="/backups"
EMAIL="alwold@gmail.com"

dump_level=`date +%w`
date_stamp=`date +%Y%m%d`
log_file=${DUMP_DIR}/backup.log.${date_stamp}
errors=0

# TODO check if dump volume is mounted?

dump ${dump_level}f ${DUMP_DIR}/dump-${dump_level}-${date_stamp}.dump / &> $log_file
if [ "$?" -ne "0" ]
  then errors=1
fi

echo "Removing old dumps" >> $log_file
find $DUMP_DIR -mtime +7 -regex ".+/dump-[1-7]-.+" -print -exec rm {} \; >> $log_file

# TODO keep one level 0 dump from each month

if [ "$errors" -ne "0" ]
then
  mail_file=/tmp/backup.mail.$$
  echo "Subject: backup errors" > $mail_file
  echo >> $mail_file
  cat $log_file >> $mail_file
  sendmail $EMAIL < $mail_file
fi
