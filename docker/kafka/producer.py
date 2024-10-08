from confluent_kafka import Producer
import json
import time
import random
from faker import Faker
import boto3
import logging

# Configure logging to only output the specific JSON log message
logging.basicConfig(level=logging.INFO, format='%(message)s')

# Lambda client setup
lambda_client = boto3.client('lambda')
LAMBDA_FUNCTION_NAME = 'eks_kafka_quicksight'

# Initialize Faker for generating realistic log data
fake = Faker()

# Kafka Producer configuration
producer_config = {
    'bootstrap.servers': 'kafka:9092',
    'client.id': 'python-producer',
}

producer = Producer(producer_config)
log_counter = 0


def generate_log_message():
    global log_counter
    log_levels = ['INFO', 'DEBUG', 'ERROR', 'WARN']
    http_methods = ['GET', 'POST', 'PUT', 'DELETE']
    status_codes = [200, 201, 400, 401, 403, 404, 500, 502, 503]

    log_identifier = f"LOG-{log_counter:06d}"
    log_counter += 1

    return {
        'log_identifier': log_identifier,
        'timestamp': time.time(),
        'log_level': random.choice(log_levels),
        'ip_address': fake.ipv4_public(),
        'user_id': fake.uuid4(),
        'method': random.choice(http_methods),
        'path': fake.uri_path(),
        'status_code': random.choice(status_codes),
        'response_time': round(random.uniform(0.1, 3.0), 3),
        'message': fake.sentence(),
    }


def invoke_lambda(log_message):
    lambda_payload = {
        "log_message": log_message
    }
    try:
        lambda_client.invoke(
            FunctionName=LAMBDA_FUNCTION_NAME,
            InvocationType='Event',
            Payload=json.dumps(lambda_payload)
        )
    except:
        pass  # Suppress all errors


def produce_message():
    message = generate_log_message()
    message_with_markers = {
        "start": "LOG_START",
        "log_message": message,
        "stop": "LOG_END"
    }
    message_json = json.dumps(message_with_markers)

    # Output only the JSON log message to logging
    logging.info(message_json)

    try:
        producer.produce('gameday', key=str(message['timestamp']), value=message_json)
        producer.flush()  # Ensure the message is sent immediately

        # Invoke Lambda for every message
        invoke_lambda(message)
    except:
        pass  # Suppress all errors silently


if __name__ == "__main__":
    try:
        while True:
            produce_message()
            time.sleep(random.uniform(1, 30))  # Random sleep between 1 and 30 seconds
    except KeyboardInterrupt:
        pass  # Suppress interruption output
