#!/bin/bash
CN=bad-partner.apps.pirate.com
echo "Create Root CA and Private Key"
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=Pirate Inc./CN=pirate.com' \
-keyout certs/pirate.com.key -out certs/pirate.com.crt
echo "Create Certificate and Private Key for $CN"
openssl req -out certs/bad-partner.csr -newkey rsa:2048 -nodes -keyout certs/bad-partner.key -subj "/CN=${CN}/O=Bad Department"
openssl x509 -req -days 365 -CA certs/pirate.com.crt -CAkey certs/pirate.com.key -set_serial 0 -in certs/bad-partner.csr -out certs/bad-partner.crt