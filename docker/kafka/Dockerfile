FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the Python script and requirements file to the container
COPY producer.py /app/

# Install Kafka Python client library
RUN pip install confluent-kafka faker

# Run the Python Kafka producer script
CMD ["python", "producer.py"]
