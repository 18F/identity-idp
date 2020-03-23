FROM python:3.8

# Install some build tools
# RUN apt-get update && apt-get install build-essential -y

COPY requirements.txt ./
RUN pip install -U pip \
    && pip install -r requirements.txt

COPY locustfile.py .
COPY foney.py .

EXPOSE 8089/tcp

CMD ["locust"]
