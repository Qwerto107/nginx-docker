FROM alpine:3.19.1

MAINTAINER qwerto107 "qwerto1007@gmail.com" 

COPY nginx.sh /tmp/nginx.sh

RUN chmod +x /tmp/nginx.sh

RUN /tmp/nginx.sh

RUN rm -f /tmp/nginx.sh

RUN mkdir -p /usr/local/nginx/geo

COPY ./geo/GeoLite2-Country.mmdb /usr/local/nginx/geo/GeoLite2-Country.mmdb

# 暴露端口
EXPOSE 80
EXPOSE 443

# 启动 Nginx
# ENTRYPOINT /usr/local/nginx/sbin/nginx -g 'daemon off;'
CMD ["/usr/local/nginx/sbin/nginx","-g","daemon off;"]