trap exit TERM
certbot reconfigure --webroot -w /acme -v -n --cert-name my_site
while :
do
  certbot renew --cert-name my_site
  echo "sleeping..."
  sleep 24h & wait ${!}
done
