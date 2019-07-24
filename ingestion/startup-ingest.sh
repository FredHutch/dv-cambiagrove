#!/bin/bash
date
echo "Validating inputs"
echo "Args: $@"
env
if [ -z "${FTPSITE}" ]; then
  echo 'FTPSITE not set. No source to download.'
fi

if [ -z "${FTPPATH}" ]; then
  echo 'FTPPATH not set. No source to download.'
fi

if [ -z "${FTPFILTER}" ]; then
  echo 'FTPFILTER not set. No source to download.'
fi

if [ -z "${FLAGS}" ]; then
  echo 'FLAGS not set. No source to download.'
fi

if [ -z "${S3DESTINATION}" ]; then
  echo 'S3DESTINATION not set. No place to put results.'
fi


echo "Upgrading Python3 and AWS CLI"
sudo apt-get -y update
sudo apt -y install awscli lftp uuid-runtime


PROCESSID=$(uuidgen)
echo "ProcessID is $PROCESSID"


echo "Creating working directory"
sudo mkdir -p /data
sudo mkdir -p /data/$PROCESSID
LOCAL_DIR="/data/$PROCESSID"


# copy inputs from S3
echo "Getting the source data from FTP"
sudo lftp -e " \
   debug -t 2; \
   set net:max-retries 3; \
   set net:timeout 10m; \
   set ftp:use-mlsd on; \
   set ftp:charset iso-8859-1; \
   open ftp://$FTPSITE; \
   mirror $FTPPATH $LOCAL_DIR $FLAGS --continue --include-glob '$FTPFILTER' --parallel=30 --log=/tmp/lftpmirror.log; \
   exit; \
   "


echo "Saving the results back to S3"
sudo aws s3 cp $LOCAL_DIR $S3DESTINATION$FTPPATH --recursive || error_exit "Failed to upload results to S3"

echo "Cleaning up"
sudo rm -rf $LOCAL_DIR/*

date
echo "Ending process. bye bye!!"