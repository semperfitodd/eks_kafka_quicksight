import json
import boto3
import logging
import os

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Define SageMaker and DynamoDB clients
sagemaker_runtime = boto3.client('sagemaker-runtime')
dynamodb = boto3.resource('dynamodb')

# Fetch the SageMaker endpoint name from environment variables
SAGEMAKER_ENDPOINT = os.environ['SAGEMAKER_ENDPOINT']
DYNAMO_TABLE_NAME = os.environ['DYNAMO_TABLE_NAME']

# Preprocessing function
def preprocess_log(log):
    # Convert log level to numeric
    log_level_map = {
        "DEBUG": 0,
        "INFO": 1,
        "WARN": 2,
        "ERROR": 3
    }

    # Extract relevant fields
    log_level = log_level_map.get(log.get('log_level', 'DEBUG'), 0)
    response_time = float(log.get('response_time', 0))

    # Construct processed log
    processed_log = [log_level, response_time]
    return processed_log

# Function to store log with RCF score in DynamoDB
def store_log_to_dynamo(log_message, rcf_score):
    try:
        # Get the DynamoDB table
        table = dynamodb.Table(DYNAMO_TABLE_NAME)

        # Prepare the log entry with the RCF score
        log_entry = {
            'log_identifier': log_message['log_identifier'],
            'timestamp': log_message['timestamp'],
            'log_level': log_message['log_level'],
            'ip_address': log_message['ip_address'],
            'user_id': log_message['user_id'],
            'method': log_message['method'],
            'path': log_message['path'],
            'status_code': log_message['status_code'],
            'response_time': log_message['response_time'],
            'message': log_message['message'],
            'rcf_score': rcf_score
        }

        # Write to DynamoDB
        table.put_item(Item=log_entry)

        logger.info(f"Log written to DynamoDB: {log_entry}")

    except Exception as e:
        logger.error(f"Error writing to DynamoDB: {str(e)}")

def lambda_handler(event, context):
    try:
        # The payload is passed as a single log entry
        log_message = event['log_message']  # Extract the log message from event

        # Preprocess the log message
        preprocessed_log = preprocess_log(log_message)

        # Convert the preprocessed log to CSV format (no spaces, just "3,1.718")
        payload = ','.join(map(str, preprocessed_log))

        # Log payload to be sent to SageMaker
        logger.info(f'Payload sent to SageMaker: {payload}')

        # Invoke SageMaker endpoint
        response = sagemaker_runtime.invoke_endpoint(
            EndpointName=SAGEMAKER_ENDPOINT,  # Use the environment variable
            ContentType='text/csv',
            Body=payload
        )

        # Log SageMaker response for debugging
        logger.info(f'SageMaker Response: {response}')

        # Parse and return response from SageMaker
        result = json.loads(response['Body'].read().decode())
        rcf_score = result.get('score', 0)  # Assume RCF returns 'score' field

        # Write log to DynamoDB with the RCF score
        store_log_to_dynamo(log_message, rcf_score)

        return {
            'statusCode': 200,
            'body': json.dumps({'result': result, 'sent_payload': payload})
        }

    except Exception as e:
        # Log any errors for debugging
        logger.error(f"Error during SageMaker invocation: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'sent_payload': payload  # Return the payload sent to SageMaker for debugging
            })
        }
