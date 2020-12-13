#!/bin/bash
function check_pod(){
    PROJECT=$1
    NUM=$2
    CONDITION=$3
    COUNT=0
    while [ ${COUNT} -lt ${NUM} ];
    do
        clear
        oc get pods -n ${PROJECT}
        sleep 5
        COUNT=$( oc get pods -n ${PROJECT} --field-selector=status.phase=Running --no-headers|wc -l)
    done
}

function backup_istio_files(){
    for file in $(ls istio/*.yaml)
    do
        file_name=$(echo $file|awk -F'.' '{print $1}')
        cp $file_name.yaml $file_name.bak
    done
}

function restore_istio_files(){
    for file in $(ls istio/*.yaml)
    do
        file_name=$(echo $file|awk -F'.' '{print $1}')
        cp $file_name.bak $file_name.yaml
    done
    rm -f istio/*.bak
}

function verify_sidecar(){
  PROJECT=$1
  for pod in $(oc get pods -n $PROJECT --no-headers -o=custom-columns='DATA:metadata.name')
  do
    NUM=$(oc get pod $pod -n $PROJECT -o jsonpath='{.spec.containers[*].name}' | wc -w)
    if [ $NUM -lt 2 ];
    then
      echo "Sidecar not found for pod $pod"
      oc delete pod $pod -n $PROJECT
    else
      echo "pod $pod already has 2 containers"
    fi
  done
}

PLATFORM=$(uname)

if ! hash oc 2>/dev/null
then
    echo "'oc' was not found in PATH"
    echo "Download from https://mirror.openshift.com/pub/openshift-v4/clients/oc/"
    exit
fi

if ! hash oc whoami 2>/dev/null
then
    echo "You need to login to your cluster with oc login --server=<URL to API>"
    exit 
fi

echo "Enter the name of Service Mesh Control Plane project: "
read CONTROL_PLANE
echo

oc get project $CONTROL_PLANE > /dev/null 2>&1
if [ $? -eq 0 ]
then
  echo "Project $CONTROL_PLANE already exists"
  sleep 2
else
  echo "Creating project: $CONTROL_PLANE"
  oc new-project $CONTROL_PLANE --display-name $CONTROL_PLANE --description="Service Mesh Control Plane"
fi

echo "Enter the name of Service Mesh Data Plane project: "
read DATA_PLANE
echo

oc get project $DATA_PLANE > /dev/null 2>&1
if [ $? -eq 0 ]
then
  echo "Project $DATA_PLANE already exists"
  sleep 2
else
  echo "Creating project: $DATA_PLANE"
  oc new-project $DATA_PLANE --display-name $DATA_PLANE --description="Service Mesh Data Plane"
fi

SUBDOMAIN=$(oc whoami --show-console  | awk -F'apps.' '{print $2}')
DOMAIN="apps.${SUBDOMAIN}"
echo "Route will under domain *.${DOMAIN}"

echo "Do you want to change domain? (y/n): "
read CHANGE_DOMAIN
echo

if [ "$CHANGE_DOMAIN" = "Y" ] || [ "$CHANGE_DOMAIN" = "y" ];
then
    echo "Enter new domain name: "
    read DOMAIN
fi

echo "Create Control Plane"
echo "Script will automatically continue to next steps when control plane is finished"
oc apply -f setup-ossm/smcp.yaml -n $CONTROL_PLANE
check_pod $CONTROL_PLANE 12 Running

echo "Join Data Plane to Control Plane"
cp setup-ossm/smmr.yaml setup-ossm/smmr.bak
echo 
if [ "$PLATFORM" = 'Darwin' ];
then
  sed -i '' 's/DATA_PLANE/'"$DATA_PLANE"'/' setup-ossm/smmr.yaml
else
  sed -i 's/DATA_PLANE/'"$DATA_PLANE"'/' setup-ossm/smmr.yaml
fi
oc apply -f setup-ossm/smmr.yaml -n $CONTROL_PLANE
mv setup-ossm/smmr.bak setup-ossm/smmr.yaml
oc describe smmr/default -n $CONTROL_PLANE | grep -A2 Spec:
sleep 5

echo "Deploy applications to $DATA_PLANE"
oc apply -f apps/deployment.yaml
check_pod $DATA_PLANE 2 Running


echo
echo "Create certificate and key for istio-ingressgateway"
oc create secret tls istio-ingressgateway-certs \
--cert certs/cert.pem \
--key certs/key.pem \
-n $CONTROL_PLANE

echo
echo "Create CA certificate for mutual TLS authentication"
oc create secret generic istio-ingressgateway-ca-certs \
--from-file=certs/ca-chain.cert.pem \
-n $CONTROL_PLANE

echo
echo "Restart istio-ingressgateway"
oc patch deployment istio-ingressgateway \
-p '{"spec":{"template":{"metadata":{"annotations":{"kubectl.kubernetes.io/restartedAt": "'`date +%FT%T%z`'"}}}}}' \
-n $CONTROL_PLANE

clear
sleep 3
oc get pods -n $CONTROL_PLANE | grep istio-ingressgateway
sleep 5

backup_istio_files

if [ "$PLATFORM" = 'Darwin' ];
then
  sed -i '' 's/DATA_PLANE/'"$DATA_PLANE"'/' istio/*.yaml
  sed -i '' 's/CONTROL_PLANE/'"$CONTROL_PLANE"'/' istio/*.yaml
  sed -i '' 's/DOMAIN/'"$DOMAIN"'/' istio/*.yaml
else
  sed -i 's/DATA_PLANE/'"$DATA_PLANE"'/' istio/*.yaml
  sed -i 's/CONTROL_PLANE/'"$CONTROL_PLANE"'/' istio/*.yaml
  sed -i 's/DOMAIN/'"$DOMAIN"'/' istio/*.yaml
fi

echo 
echo "Apply istio configuration for mutual TLS authentication to applications"
oc apply -f istio/backend-destination-rule.yaml -n $DATA_PLANE
oc apply -f istio/backend-virtual-service.yaml -n $DATA_PLANE
oc apply -f istio/backend-policy.yaml -n $DATA_PLANE
oc apply -f istio/frontend-destination-rule.yaml -n $DATA_PLANE
oc apply -f istio/frontend-virtual-service.yaml -n $DATA_PLANE
oc apply -f istio/frontend-policy.yaml -n $DATA_PLANE
echo 
echo "Create Gateway and Route"
oc apply -f istio/gateway.yaml -n $CONTROL_PLANE
oc apply -f istio/route.yaml -n $CONTROL_PLANE

restore_istio_files


FRONTEND_URL="$(oc get route frontend -n $CONTROL_PLANE -o jsonpath='{.spec.host}' )"
KIALI_URL="$(oc get route kiali -n $CONTROL_PLANE -o jsonpath='{.spec.host}')"

echo
echo "Check pods in $DATA_PLANE"
verify_sidecar $DATA_PLANE

echo
echo "Frontend URL: https://$FRONTEND_URL"


echo
echo "Test without client certificate"
echo "Press anykey to continue..."
read
echo

curl -kv https://$FRONTEND_URL


echo
echo "Test with client TLS authentication"
echo "Press anykey to continue..."
read
echo

curl -kv --cacert certs/ca-chain.cert.pem \
--cert certs/client.cert.pem \
--key certs/client.key.pem \
https://$FRONTEND_URL

echo
echo "You can test with cURL by:"
echo "curl -kv --cacert certs/ca-chain.cert.pem \
--cert certs/client.cert.pem \
--key certs/client.key.pem \
https://$FRONTEND_URL"

echo
echo "Check Kiali Console at https://$KIALI_URL"



#curl: (35) error:1401E410:SSL routines:CONNECT_CR_FINISHED:sslv3 alert handshake failure

