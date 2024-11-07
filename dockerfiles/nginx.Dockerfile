FROM public.ecr.aws/docker/library/alpine:3

RUN apk add --no-cache jq curl nginx nginx-mod-http-headers-more
RUN apk upgrade --no-cache

COPY ./dockerfiles/update-ips.sh /update-ips.sh
COPY ./dockerfiles/nginx-prod.conf /etc/nginx/nginx.conf
COPY ./dockerfiles/status-map.conf /etc/nginx/
RUN /update-ips.sh

ENTRYPOINT ["/usr/sbin/nginx"]
