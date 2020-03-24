FROM python:3.8

# You can build a one-off container like this:
# docker build -f load-test.Dockerfile -t idp-locust .
# docker run --rm -p 8089:8089 idp-locust
# open http://127.0.0.1:8089 to access

COPY requirements.txt ./
RUN pip install -U pip \
    && pip install -r requirements.txt

COPY locustfile.py .
COPY foney.py .

EXPOSE 8089/tcp

CMD ["locust"]
