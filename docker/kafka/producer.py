from confluent_kafka import Producer
import json
import time
import random
from faker import Faker

# Initialize Faker for generating realistic log data
fake = Faker()

# Kafka Producer configuration
producer_config = {
    'bootstrap.servers': 'kafka:9092',
    'client.id': 'python-producer',
}

# Initialize the producer
producer = Producer(producer_config)

# Initialize a log identifier counter
log_counter = 0


# Helper function to generate a realistic log message
def generate_log_message():
    global log_counter
    log_levels = ['INFO', 'DEBUG', 'ERROR', 'WARN']
    http_methods = ['GET', 'POST', 'PUT', 'DELETE']
    status_codes = [200, 201, 400, 401, 403, 404, 500, 502, 503]

    # Create a sequential log identifier
    log_identifier = f"LOG-{log_counter:06d}"  # This will generate IDs like LOG-000001, LOG-000002, etc.
    log_counter += 1

    log_message = {
        'log_identifier': log_identifier,  # Add the log identifier to the message
        'timestamp': time.time(),
        'log_level': random.choice(log_levels),
        'ip_address': fake.ipv4_public(),
        'user_id': fake.uuid4(),
        'method': random.choice(http_methods),
        'path': fake.uri_path(),
        'status_code': random.choice(status_codes),
        'response_time': round(random.uniform(0.1, 3.0), 3),  # Simulated response time in seconds
        'message': fake.sentence(),
    }

    return log_message


# Helper function to determine if a message is an outlier
def is_outlier(log_message):
    # Reduce the prevalence of outliers by making them more rare
    outlier_conditions = [
        log_message['response_time'] > 2.9,  # Response time greater than 2.9 seconds (less frequent)
        log_message['status_code'] >= 500 and random.random() < 0.2,
        # 20% chance for status code >= 500 to be an outlier
        log_message['log_level'] == 'ERROR' and random.random() < 0.1  # 10% chance for ERROR level to be an outlier
    ]

    return any(outlier_conditions)


# Function to produce messages to Kafka with start and stop markers
def produce_message():
    message = generate_log_message()

    # Wrap the log message with start and stop markers
    message_with_markers = {
        "start": "LOG_START",
        "log_message": message,
        "stop": "LOG_END"
    }

    # Convert to JSON
    message_json = json.dumps(message_with_markers)

    # Send message to the gameday topic
    producer.produce('gameday', key=str(message['timestamp']), value=message_json)

    # If the message is an outlier, also send it to the gameday-outliers topic
    if is_outlier(message):
        print(f"Outlier detected: {message_json}")  # Debug to see detected outliers
        producer.produce('gameday-outliers', key=str(message['timestamp']), value=message_json)

    producer.flush()


# Produce messages at random intervals between 1 and 30 seconds
if __name__ == "__main__":
    try:
        while True:
            produce_message()
            print("Message sent successfully!")
            time.sleep(random.uniform(1, 30))  # Produce one message at a random interval between 1 and 30 seconds
    except KeyboardInterrupt:
        print("Producer stopped.")
