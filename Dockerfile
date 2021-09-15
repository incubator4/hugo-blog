FROM klakegg/hugo:0.74.3-onbuild as builder

FROM nginx:alpine as web
RUN rm -rf /usr/share/nginx/html/*
COPY --from=builder /target /usr/share/nginx/html