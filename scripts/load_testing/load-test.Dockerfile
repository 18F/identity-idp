FROM python:3

# Install some build tools
# RUN apt-get update && apt-get install build-essential -y

COPY requirements.txt ./
RUN pip install -r requirements.txt

CMD ["locust"]