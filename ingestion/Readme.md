# Ingesting Data


## Copying FTP data

Download from an FTP site to a VM (container) using lftp

* Useful guide: [Transfer files from an FTP server to S3](https://hackncheese.com/2014/11/24/Transfer-files-from-an-FTP-server-to-S3/)
* LFTP docs, https://lftp.yar.ru/desc.html
* Examples:
    * http://www.russbrooks.com/2010/11/19/lftp-cheetsheet
    * https://linoxide.com/linux-how-to/lftp-commands/
    * http://www.tutorialspoint.com/unix_commands/lftp.htm
    * https://www.cyberciti.biz/faq/lftp-mirror-example/


```
export FTPSITE=ftp.ncbi.nlm.nih.gov
export FTPPATH=/gene/DATA/GENE_INFO
export FTPFILTER="*"
export S3DESTINATION=s3://sttr-viz-ingestion/ncbi/gene
export FLAGS=""

echo $FTPSITE
echo $FTPPATH
echo $FTPFILTER
echo $S3DESTINATION
echo $FLAGS

. startup-ingest.sh
```




## AWS Batch Setup


### Container Setup

This is in the /fetch-and-run-container folder


### Make a fetch-and-run container


based on https://aws.amazon.com/blogs/compute/creating-a-simple-fetch-and-run-aws-batch-job/ and https://github.com/awslabs/aws-batch-helpers

```
sudo -i
apt-get update
apt-get -y install awscli docker.io

cd $HOME
mkdir -p fetchimage
cd fetchimage

nano # create the Dockerfile
nano # create the fetch-and-run script


docker build -t ingestion/dv-ingest .   
docker images

apt-get list | grep g++
```

```
aws configure  # specify credentials
aws ecr get-login --region us-west-2

docker login -u AWS -p <long_key> <aws_ecr_url>



# tag a container so it can be uploaded
docker tag cortex-discovery/fast-ingest <aws_ecr_url_without_https>/cortex-discovery:fast-ingest

docker push <aws_ecr_url_without_https>/cortex-discovery:fast-ingest

```

ECR URL - 561666204077.dkr.ecr.us-west-2.amazonaws.com/ingestion

### AMI Setup


**EBS Volume and Custom AMI Approach**

* Using https://aws.amazon.com/blogs/compute/building-high-throughput-genomic-batch-workflows-on-aws-batch-layer-part-3-of-4/ directly

* use the EC2 console to connect to the VM
```
ssh -i "<private-key-name>.pem" ec2-user@<vm-url>
```

* run this against the VM:

```
sudo yum -y update
sudo mkfs -t ext4 /dev/sdb
sudo mkdir /docker_scratch
sudo echo -e '/dev/sdb\t/docker_scratch\text4\tdefaults\t0\t0' | sudo tee -a /etc/fstab
sudo mount –a
sudo systemctl stop ecs 
sudo rm -rf /var/lib/ecs/data/ecs_agent_data.json


```

* Then create an AMI, based on https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/creating-an-ami-ebs.html 

```
ami-00695c4b435ddf547
```
* Update the compute environment to use the AMI
* Also update the job definition to update the mounts, per https://aws.amazon.com/blogs/compute/building-high-throughput-genomic-batch-workflows-on-aws-batch-layer-part-3-of-4/ : 

```
"mountPoints": [{"containerPath": "/data", "readOnly": false, "sourceVolume": "docker_scratch"}],
"volumes": [{"name": "docker_scratch", "host": {"sourcePath": "/docker_scratch"}}]
```





### Resources

* [Traversing an FTP Listing in Python](https://stackoverflow.com/questions/1854572/traversing-ftp-listing)
* [FTPLib](https://docs.python.org/3/library/ftplib.html)
* [aws_lambda_ftp_function.py](https://github.com/orasik/aws_lambda_ftp_function/blob/master/aws_lambda_ftp_function.py)
* [FTP copy with Python](https://stackoverflow.com/questions/41171784/trouble-transferring-data-from-ftp-server-to-s3-via-stream-using-python)
* [Sync FTP to S3 py](https://github.com/vangheem/sync-ftp-to-s3/blob/master/sync-ftp-to-s3.py)
* [Transfer File From FTP Server to AWS S3 Bucket Using Python](https://medium.com/better-programming/transfer-file-from-ftp-server-to-a-s3-bucket-using-python-7f9e51f44e35)
* [Pyftpsync-s3](https://pypi.org/project/pyftpsync-s3/)
* [How to copy large numbers of files](https://serverfault.com/questions/18125/how-to-copy-a-large-number-of-files-quickly-between-two-servers) 
* [How to copy 15TB of files](https://serverfault.com/questions/721223/transfer-15tb-of-tiny-files?rq=1)
* [How to sync](https://www.quora.com/How-can-I-sync-an-FTP-server-with-Amazon-S3)
* [How to sync w/ Lambda](https://www.quora.com/How-can-I-sync-S3-with-an-FTP-server-using-the-Lambda-function)
