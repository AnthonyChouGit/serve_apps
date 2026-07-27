#!/bin/sh
while :
do
  sleep 24h
  nginx -t && nginx -s reload
done &
