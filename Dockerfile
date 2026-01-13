FROM debian:stable AS builder
COPY nginx.sh /tmp/nginx.sh
RUN chmod +x /tmp/nginx.sh && /tmp/nginx.sh

FROM debian:stable-slim AS runner
RUN groupadd -r www && useradd -r -g www -s /usr/sbin/nologin www
COPY --from=builder --chown=www:www /usr/local/nginx /usr/local/nginx
CMD ["/usr/local/nginx/sbin/nginx","-g","daemon off;"]
