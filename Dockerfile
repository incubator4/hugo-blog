FROM golang:alpine as builder
RUN  sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && \
    apk --no-cache update && apk  --no-cache add git
RUN go get -u -v github.com/gohugoio/hugo
WORKDIR /app
ADD . .
RUN hugo

FROM nginx as web
COPY --from=builder /app/public /usr/share/nginx/html