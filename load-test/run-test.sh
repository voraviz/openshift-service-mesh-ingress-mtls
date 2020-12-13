#!/bin/sh
JMETER_BASE_PATH=~/opt/apache-jmeter-5.2.1
HOST=$1
THREAD=$2
LOOP=$3
JMX_FILE=frontend-mtls.jmx
TEST_RESULT=testresults.jtl
$JMETER_BASE_PATH/bin/jmeter \
-Djavax.net.ssl.trustStore=truststore.jks \
-Djavax.net.ssl.keyStore=keystore.jks \
-Djavax.net.ssl.keyStorePassword=password \
-Jhttps.use.cached.ssl.context=false \
-n -t $JMX_FILE -l $TEST_RESULT \
-Jthread=$THREAD -Jloop=$LOOP -Jhost=$HOST