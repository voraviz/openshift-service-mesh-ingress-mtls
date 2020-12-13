#!/bin/sh
# Create Trust Store
keytool -importcert -alias test-ca-chain-cert -file ../ossm2/certs/ca-chain.cert.pem -keystore truststore.jks -storepass password
#keytool -importcert -alias client-cert -file ../ossm2/certs/client.cert.pem -keystore truststore.jks -storepass password
# Key Store
cat ../ossm2/certs/client.cert.pem ../ossm2/certs/ca-chain.cert.pem > client.pem
openssl pkcs12 -export -inkey ../ossm2/certs/client.key.pem -in client.pem -name client-cert -out client-cert.p12
keytool -importkeystore -srckeystore client-cert.p12 -srcstoretype pkcs12 -destkeystore keystore.jks
#cat ../ossm2/certs/client.cert.pem ../ossm2/certs/client.key.pem > client.pem

#keytool -import -trustcacerts -alias client-cert -file client.pem -keystore keystore.jks -storepass password
# keytool -import -alias client-cert -file ../ossm2/certs/client.cert.pem -keystore keystore.jks -storepass password
# openssl pkcs12 -export -out client.key.p12 -in ../ossm2/certs/client.key.pem
# keytool -import -v -trustcacerts -alias client-key -file ../ossm2/certs/client.key.pem -keystore truststore.jks
# keytool -importkeystore -destkeystore keystore.jks -srckeystore client.key.p12 -srcstoretype pkcs12 -alias client-key -storepass password
#~/opt/apache-jmeter-5.2.1/bin/jmeter -Djavax.net.ssl.trustStore=truststore.jks -Djavax.net.ssl.keyStore=keystore.jks -Djavax.net.ssl.keyStorePassword=password -Jhttps.use.cached.ssl.context=false
# jmeter -n –t test.jmx -l testresults.jtl.