FROM nginx:alpine as web
RUN rm -rf /usr/share/nginx/html/*
ADD public /usr/share/nginx/html