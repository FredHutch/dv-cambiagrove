import json
import boto3
import os
from datetime import datetime
import time
import traceback
import csv
import io

# Config variables. These come from environment variables
var_job_queue = os.environ['JOB_QUEUE']
var_job_definition = os.environ['JOB_DEF']
var_batch_file_s3_url = os.environ['BATCH_S3_URL']
var_cpu_count = os.environ['CPU_COUNT']
var_mem_mb = os.environ['MEM_MB']

var_s3_csv_source_bucket = os.environ['S3_SOURCE_BUCKET']
var_s3_csv_source_key = os.environ['S3_SOURCE_KEY']

var_command_script = 'startup-ftp-ingest.sh'
var_job_name = 'dv-ingestion-{}'.format(datetime.now().strftime("%Y-%m-%d-%H-%M-%S"))


# -------------------------------------------------------------------------------------------------------------------
# Helper methods
# -------------------------------------------------------------------------------------------------------------------
def log(logType='INFO', header=None, message=None):
    print(f'{logType}: {header} {message}')


def try_parse_int(s, base=10, val=None):
    try:
        return int(s, base)
    except ValueError:
        return val


def get_s3_object(aws_client, s3_bucket, s3_key, retry_wait_sec=2, do_retry=True):
    headerName = 'get_s3_object'
    log(header = headerName, message = f"Getting object s3://{s3_bucket}/{s3_key}")
    try:
        response = aws_client.get_object(Bucket=s3_bucket, Key=s3_key)
        if response.get('Body') is not None:
            return response['Body']
        else:
            return None
    except Exception as E:
        log(logType=logTypeError, header= headerName, 
            message=f"Unable to get {s3_bucket}/{s3_key}, retrying")
        tracer = traceback.format_exc()
        type_e, value, ignore = sys.exc_info()
        log(logType="ERROR", header=headerName,
                      message=f"Error getting {s3_bucket}/{s3_key} : {repr(E)} {type_e} value {tracer}")
        print(E)
        if do_retry:
            time.sleep(retry_wait_sec)
            return get_s3_object(aws_client, s3_bucket, s3_key, do_retry=False)
        else:
            exit(3)


def create_batch_job(  ftp_source
                     , s3_destination
                     , path
                     , file_filter
                     , flags
                     , cpu_count
                     , mem_mb
                     , job_name
                     , job_queue
                     , job_definition
                     , client
                     , batch_file_s3_url
                     , command):
    response = client.submit_job(
        jobName = job_name
        ,jobQueue = job_queue
        ,jobDefinition=job_definition
        ,containerOverrides={
            'vcpus': cpu_count,
            'memory': mem_mb,
            'command': [
                command,
            ],
            "environment": [ 
             { 
                "name": "BATCH_FILE_TYPE",
                "value": "script"
             },
             { 
                "name": "BATCH_FILE_S3_URL",
                "value": batch_file_s3_url
             },
             { 
                "name": "FTPSITE",
                "value": ftp_source
             },
             { 
                "name": "S3DESTINATION",
                "value": s3_destination
             },
             { 
                "name": "FTPPATH",
                "value": path
             },
             { 
                "name": "FTPFILTER",
                "value": file_filter
             },
             { 
                "name": "FLAGS",
                "value": flags
             }
            ]
        }
        )
    return response

def start_batch_ingest(ftp_source, path, file_filter, s3_destination, flags):
    batch_client = boto3.client('batch', region_name='us-west-2')
    log(header="Starting Batch job {}".format(var_job_name))
    return create_batch_job(ftp_source = ftp_source
                     , s3_destination = s3_destination
                     , path = path
                     , file_filter = file_filter
                     , flags = flags
                     , cpu_count = try_parse_int(var_cpu_count)
                     , mem_mb = try_parse_int(var_mem_mb)
                     , job_name = var_job_name
                     , job_queue = var_job_queue
                     , job_definition = var_job_definition
                     , client = batch_client
                     , batch_file_s3_url = var_batch_file_s3_url
                     , command = var_command_script)


def lambda_handler(event, context):
    print(f'********event={event}')
    try:
        # first, get the CSV file
        aws_client = boto3.client('s3', region_name='us-west-2')
        csv_config = get_s3_object(aws_client, var_s3_csv_source_bucket, var_s3_csv_source_key).read().decode('utf-8').split('\n')
        #print('{} {} {}'.format(type(csv_config), csv_config, csv_config[0]))
        csv_reader = csv.DictReader(csv_config, fieldnames=('ftpsite', 'path', 'filter', 'destination','flags','enabled'))
        config_entries = []
        for row in csv_reader:
            config_entries.append(row)
        # second, start batch processing
        for config in config_entries:
            ftp_source = config.get('ftpsite')
            s3_destination = config.get('destination')
            if ftp_source.find('ftpsite') < 0:
                print('{} {}'.format(ftp_source, s3_destination))
                if try_parse_int(config.get('enabled')) == 1:
                    batch_start_response = start_batch_ingest(ftp_source = ftp_source
                                                    ,s3_destination = s3_destination
                                                    ,path = config.get('path','')
                                                    ,file_filter = config.get('filter','')
                                                    ,flags =  config.get('flags',''))
                    log(header="AWS Batch process started", message=batch_start_response)
        # craft result for the next step in the ingestion workflow
        result = {
            "statusCode": 200
        }
        log(header="Validation result", message=str(result))
        return result
    except Exception as E:
        log(logType="ERROR", header="lambda_handler",
            message="{}".format(repr(E)))
        exit(3)
