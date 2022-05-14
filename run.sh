#!/bin/sh
sudo docker-compose down || true

sudo docker-compose rm -f && \
sudo docker-compose build && \
sudo docker-compose up

