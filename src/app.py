import json
import os
import uuid
from datetime import datetime
import boto3

# Initialize clients outside the handler for execution context reuse
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

# Retrieve environment variables set by Terraform
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME')

def lambda_handler(event, context):
    try:
        # 1. Parse incoming request body from API Gateway
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        record_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()

        # 2. Store the raw payload in S3
        s3_key = f"payloads/{timestamp}-{record_id}.json"
        s3_client.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=s3_key,
            Body=json.dumps(body),
            ContentType='application/json'
        )

        # 3. Save metadata into DynamoDB
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)
        table.put_item(
            Item={
                'id': record_id,
                'timestamp': timestamp,
                'status': 'PROCESSED',
                's3_location': s3_key,
                'summary': body.get('summary', 'No summary provided')
            }
        )

        # 4. Return success response to the API Gateway caller
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'message': 'Payload processed successfully',
                'id': record_id,
                's3_key': s3_key
            })
        }

    except Exception as e:
        print(f"Error processing payload: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Failed to process payload'})
        }