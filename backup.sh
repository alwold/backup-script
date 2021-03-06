#!/bin/bash

DUMP_DIR="/backups"
# the postgres dump dir must be writable by the postgres user
POSTGRES_DUMP_DIR="/backups/postgres"
POSTGRES_USER="postgres"
EMAIL="alwold@alwold.com"

dump_level=`date +%w`
date_stamp=`date +%Y%m%d`
log_file=${DUMP_DIR}/logs/backup.log.${date_stamp}
errors=0

# TODO check if dump volume is mounted?

# backup the root partition
/sbin/dump -h 0 -${dump_level}uf ${DUMP_DIR}/dump-${dump_level}-${date_stamp}.dump / &> $log_file
if [ "$?" -ne "0" ]
  then errors=1
fi

# backup postgres
mkdir -p $POSTGRES_DUMP_DIR
chown $POSTGRES_USER $POSTGRES_DUMP_DIR
cd $POSTGRES_DUMP_DIR
for db in `su -c "psql -A -t -c \"select datname from pg_database\"" ${POSTGRES_USER}`; do
  if [ "$db" != "crawl" ]; then
    su -c "pg_dump $db | gzip > ${POSTGRES_DUMP_DIR}/$db-${date_stamp}.dump" ${POSTGRES_USER} &>>$log_file
    if [ "$?" -ne "0" ]
      then errors=1
    fi
  fi
done

echo "Removing old dumps" >> $log_file
# remove anything older than 7 days that isn't level 0
find $DUMP_DIR -mtime +7 -regex ".+/dump-[1-7]-.+" -print -exec rm {} \; >> $log_file

# keep one level 0 dump from each month
echo "Removing dumps except for one level 0 for each month" >> $log_file
for i in `find $DUMP_DIR -maxdepth 1 -mtime +30 -regex ".+/dump-0-.+" | sort`; do
  prefix=`basename $i`
  prefix=${prefix:0:13}
  if [ "$prefix" = "$current_prefix" ]
  then
    echo $i >> $log_file
    rm $i
  else
    current_prefix=$prefix
  fi
done

# remove level 0 dumps that are older than a year
find $DUMP_DIR -mtime +365 -name "dump-0-*" -print -exec rm {} \; >> $log_file

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
