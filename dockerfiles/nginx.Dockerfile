FROM public.ecr.aws/docker/library/alpine:3.20

RUN apk upgrade --no-cache
RUN apk add --no-cache jq curl nginx nginx-mod-http-headers-more openssl

COPY ./dockerfiles/update-ips.sh /update-ips.sh
COPY ./dockerfiles/nginx-prod.conf /etc/nginx/nginx.conf
COPY ./dockerfiles/status-map.conf /etc/nginx/
RUN /update-ips.sh

RUN mkdir -p /var/lib/nginx/tmp/client_body \
             /var/lib/nginx/tmp/proxy_temp \
             /var/lib/nginx/tmp/fastcgi_temp \
             /var/lib/nginx/tmp/uwsgi_temp \
             /var/lib/nginx/tmp/scgi_temp \
             /var/lib/nginx/logs && \
    chown -R 100:1000 /var/lib/nginx && \
    chmod -R 755 /var/lib/nginx

# Generate and place SSL certificates for nginx (used only by ALB)
RUN mkdir /keys
RUN openssl req -x509 -sha256 -nodes -newkey rsa:2048 -days 1825 \
    -keyout /keys/localhost.key \
    -out /keys/localhost.crt \
    -subj "/C=US/ST=Fake/L=Fakerton/O=Dis/CN=localhost" && \
    chmod 644 /keys/localhost.key /keys/localhost.crt

ENTRYPOINT ["/usr/sbin/nginx"]
