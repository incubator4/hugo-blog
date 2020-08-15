FROM golang:alpine as builder
RUN go get -u -v github.com/gohugoio/hugo
WORKDIR /app
ADD . .
RUN hugo

FROM nginx as web
COPY --from=builder /app/public /usr/share/nginx/html