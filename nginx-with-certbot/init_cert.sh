docker run --rm -v ./certbot/etc/letsencrypt:/etc/letsencrypt \
                -v ./certbot/var/lib/letsencrypt:/var/lib/letsencrypt \
                -p 80:80 \
                certbot/certbot certonly --cert-name my_site --standalone -n \
                -d example.com \
                -d synctv.example.com \
                -d www.example.com \
                -m your_email@example.com \
                --agree-tos \
                -v
