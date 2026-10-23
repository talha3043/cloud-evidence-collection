import os
import json
import time
import base64
import boto3
from botocore.exceptions import ClientError

s3 = boto3.client('s3')

def lambda_handler(event, context):
    start_time = time.time()
    
    bucket = os.environ.get('BUCKET')
    prefix = os.environ.get('PREFIX', '')
    fn_name = context.function_name

    raw_path = event.get('rawPath', '/')
    if raw_path == '/' or raw_path == '/index.html':
        target_file = 'index.html'
        content_type = 'text/html'
        is_binary = False
    elif raw_path == '/style.css':
        target_file = 'style.css'
        content_type = 'text/css'
        is_binary = False
    elif raw_path == '/cv.pdf':
        target_file = 'cv.pdf'
        content_type = 'application/pdf'
        is_binary = True
    else:
        duration_ms = int((time.time() - start_time) * 1000)
        print(json.dumps({"fn": fn_name, "path": raw_path, "status": 404, "ms": duration_ms}))
        return {
            "statusCode": 404,
            "headers": {"Content-Type": "text/html"},
            "body": "<html><body><h1>404 Not Found</h1></body></html>"
        }

    s3_key = f"{prefix.rstrip('/')}/{target_file}".lstrip('/')

    try:
        obj = s3.get_object(Bucket=bucket, Key=s3_key)
        body_bytes = obj['Body'].read()

        headers = {"Content-Type": content_type}

        if target_file == 'index.html':
            headers["Cache-Control"] = "max-age=60"
            html_content = body_bytes.decode('utf-8')
            html_content = html_content.replace('{{HOSTED_ON}}', f"Lambda {fn_name}")
            body = html_content
            b64_encoded = False
        elif is_binary:
            body = base64.b64encode(body_bytes).decode('utf-8')
            b64_encoded = True
        else:
            body = body_bytes.decode('utf-8')
            b64_encoded = False

        status_code = 200

    except ClientError:
        status_code = 404
        body = "<html><body><h1>404 Not Found</h1></body></html>"
        headers = {"Content-Type": "text/html"}
        b64_encoded = False

    duration_ms = int((time.time() - start_time) * 1000)
    print(json.dumps({"fn": fn_name, "path": raw_path, "status": status_code, "ms": duration_ms}))

    return {
        "statusCode": status_code,
        "headers": headers,
        "isBase64Encoded": b64_encoded,
        "body": body
    }
