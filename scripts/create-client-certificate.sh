#!/bin/bash
CN=great-partner.apps.acme.com
echo "Create Root CA and Private Key"
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=Acme Inc./CN=acme.com' \
-keyout certs/acme.com.key -out certs/acme.com.crt
echo "Create Certificate and Private Key for $CN"
openssl req -out certs/great-partner.csr -newkey rsa:2048 -nodes -keyout certs/great-partner.key -subj "/CN=${CN}/O=Great Department"
openssl x509 -req -days 365 -CA certs/acme.com.crt -CAkey certs/acme.com.key -set_serial 0 -in certs/great-partner.csr -out certs/great-partner.crt