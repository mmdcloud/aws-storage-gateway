import json
import os
import boto3

sgw = boto3.client('storagegateway')
FILE_SHARE_ARN = os.environ.get('FILE_SHARE_ARN')


def handler(event, context):
    print(f"Triggered by event: {json.dumps(event)}")
    if not FILE_SHARE_ARN:
        print("Error: FILE_SHARE_ARN environment variable not configured.")
        return {"statusCode": 400, "body": "FILE_SHARE_ARN missing"}
    try:
        resp = sgw.refresh_cache(FileShareARN=FILE_SHARE_ARN)
        print(f"Successfully refreshed cache. NotificationId: {resp.get('NotificationId')}")
        return {"statusCode": 200, "body": resp}
    except Exception as e:
        print(f"Error executing refresh_cache: {str(e)}")
        raise e
