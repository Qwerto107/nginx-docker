MAINTAINER qwerto107 "qwerto1007@gmail.com"

FROM alpine:3.22 AS Builder
COPY nginx.sh /tmp/nginx.sh
RUN chmod +x /tmp/nginx.sh && /tmp/nginx.sh

FROM alpine:3.22 AS Runner
RUN addgroup -S www && adduser -S www -G www
COPY --from=Builder --chown=www:www /usr/local/nginx /usr/local/
CMD ["/usr/local/nginx/sbin/nginx","-g","daemon off;"]
