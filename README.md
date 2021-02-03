# Mutual TLS ingress gateway with OpenShift Service Mesh

![banner](images/banner.jpg)
<!-- TOC -->

- [Mutual TLS ingress gateway with OpenShift Service Mesh](#mutual-tls-ingress-gateway-with-openshift-service-mesh)
  - [Prerequisites](#prerequisites)
  - [Step by Step setup](#step-by-step-setup)
    - [Setup Control Plane, Data Plane and Deploy Demo Application](#setup-control-plane-data-plane-and-deploy-demo-application)
    - [Secure backend and frontend with mTLS](#secure-backend-and-frontend-with-mtls)
    - [Health Check](#health-check)
    - [Configure Gateway with TLS](#configure-gateway-with-tls)
    - [Configure Gateway with mTLS](#configure-gateway-with-mtls)
  - [Interactive Command Line setup](#interactive-command-line-setup)

<!-- /TOC -->
## Prerequisites

Prerequistes are install Operators requried by OpenShift Service Mesh. You need to install following Operators from OperatorHub.

  - ElasticSearch
  - Jaeger
  - Kiali
  - OpenShift Service Mesh
  
## Step by Step setup

### Setup Control Plane, Data Plane and Deploy Demo Application
- Create control plane
  
  ```bash
  #Create namespace for control plane
  oc new-project control-plane --display-name="Control Plane"
  
  #Create control plane
  oc create -f https://raw.githubusercontent.com/voraviz/openshift-service-mesh-ingress-mtls/main/setup-ossm/smcp.yaml -n control-plane
  
  #Wait couple of minutes for operator to creating control plane
  #You can check status by
  oc get smcp basic-install -n control-plane
  ```
- Create data plane and join data plane to control plane

  ```bash
  #Create data plane project
  oc new-project data-plane --display-name="Data Plane"

  #Join data-plane namespace into control-plane
  oc create -f https://raw.githubusercontent.com/voraviz/openshift-service-mesh-istio-gateway/main/member-roll.yaml -n control-plane
  ```

- Deploy sample application

  ```bash
  oc apply -f https://raw.githubusercontent.com/voraviz/openshift-service-mesh-ingress-mtls/main/apps/deployment.yaml -n data-plane
  ```
- Create Destination Rule and Virtual Service for backend
  
  ```bash
  #Create Destination Rule - backend service
  oc apply -f https://raw.githubusercontent.com/voraviz/openshift-service-mesh-ingress-mtls/main/config/backend-destination-rule.yaml
  
  #Create Virtual Service - backend service
  oc apply -f https://raw.githubusercontent.com/voraviz/openshift-service-mesh-ingress-mtls/main/config/backend-virtual-service.yaml
  ```
- Create Gateway, Destination Rule and Virtual Service for frontend
  
  ```bash
  #Get OpenShift Domain from Console's URL this default subdomain to "apps"
  SUBDOMAIN=$(oc whoami --show-console  | awk -F'apps.' '{print $2}')
  DOMAIN="apps.${SUBDOMAIN}"

  #Create Destination Rule
  oc apply -f https://raw.githubusercontent.com/voraviz/openshift-service-mesh-ingress-mtls/main/config/frontend-destination-rule.yaml

  #Create Gateway - replaced DOMAIN cluster to yaml
  curl -s  https://raw.githubusercontent.com/voraviz/openshift-service-mesh-ingress-mtls/main/config/gateway.yaml|sed 's/DOMAIN/'"$DOMAIN"'/'| oc apply -f -

  #Create Virtual Service - replaced DOMAIN cluster to yaml
  curl -s  https://raw.githubusercontent.com/voraviz/openshift-service-mesh-ingress-mtls/main/config/frontend-virtual-service.yaml| sed 's/DOMAIN/'"$DOMAIN"'/' | oc apply -f -
  ```
- Check our application on Developer Console
- Check Istio Config on Kiali Console
- Test application
  
  ```bash
  # DOMAIN is your cluster Domain
  curl http://frontend.$DOMAIN
  # Sample output
  Frontend version: 1.0.0 => [Backend: http://backend:8080/version, Response: 200, Body: Backend version:v1, Response:200, Host:backend-v1-58ff89cccc-pchmp, Status:200, Message: ]
  ```

### Secure backend and frontend with mTLS
- secure backend with STRICT mTLS

  ```bash
  oc apply -f https://raw.githubusercontent.com/voraviz/openshift-service-mesh-ingress-mtls/main/config/backend-peer-authentication.yaml
  oc apply -f https://raw.githubusercontent.com/voraviz/openshift-service-mesh-ingress-mtls/main/config/backend-destination-rule-mtls.yaml
  ```
- secure frontend with STRICT mTLS
  
  ```bash
  oc apply -f https://raw.githubusercontent.com/voraviz/openshift-service-mesh-ingress-mtls/main/config/frontend-peer-authentication.yaml
  oc apply -f https://raw.githubusercontent.com/voraviz/openshift-service-mesh-ingress-mtls/main/config/frontend-destination-rule-mtls.yaml
  ```

### Health Check
- Add health check to backend
  
  ```bash
  #Pause Rollout
  oc rollout pause deployment backend-v1 -n data-plane
  #Set Readiness Probe
  oc set probe deployment backend-v1 --readiness --get-url=http://:8080/health/ready --failure-threshold=1 --initial-delay-seconds=5 --period-seconds=5 -n data-plane

  #Set Liveness Probe
  oc set probe deployment backend-v1 --liveness --get-url=http://:8080/health/live --failure-threshold=1 --initial-delay-seconds=5 --period-seconds=5 -n data-plane

  #Resume Rollout
  oc rollout resume deployment backend-v1 -n data-plane
  ```
- Annotate backend deployment for redirect HTTP probe
  
  ```bash
  oc patch deployment/backend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/rewriteAppHTTPProbers":"true"}}}}}'
  ```
- Check Kiali Graph. Dark blue line on lower part of diagram is health check traffic and green line is traffic from gateway to fronend and then to backend that is secured by mTLS (lock icon)
  
  ![kiali](images/kiali-graph-frontend-backend.png)
  
- Test that pod without sidecar cannot access backend
  
  ```bash
  oc run test-station -n data-plane -i --image=quay.io/voravitl/backend-native:v1 --rm=true  --restart=Never -- curl -vs http://backend:8080

  # Sample Output
  * Rebuilt URL to: http://backend:8080/
  *   Trying 172.30.77.122...
  * TCP_NODELAY set
  * Connected to backend (172.30.77.122) port 8080 (#0)
  > GET / HTTP/1.1
  > Host: backend:8080
  > User-Agent: curl/7.61.1
  > Accept: */*
  >
  * Recv failure: Connection reset by peer
  * Closing connection 0
  pod "test-station" deleted
  ```
  
### Configure Gateway with TLS
- Create CA, Private Key and Certificate for Gateway
  - use [create-certificate.sh](scripts/create-client-certificate.sh)
  
    ```bash
    mkdir -p certs
    scripts/create-client-certificate.sh
    ```

  - Alternatively, run following command
    
    ```bash
    #!/bin/bash
    mkdir -p certs
    SUBDOMAIN=$(oc whoami --show-console  | awk -F'apps.' '{print $2}')
    CN=frontend.apps.$SUBDOMAIN
    echo "Create Root CA and Private Key"
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=example Inc./CN=example.com' \
    -keyout certs/example.com.key -out certs/example.com.crt
    echo "Create Certificate and Private Key for $CN"
    openssl req -out certs/frontend.csr -newkey rsa:2048 -nodes -keyout certs/frontend.key -subj "/CN=${CN}/O=Great Department"
    openssl x509 -req -days 365 -CA certs/example.com.crt -CAkey certs/example.com.key -set_serial 0 -in certs/frontend.csr -out certs/frontend.crt
    ```

- Create secret to CA, Private Key and Cerfificate
  
  ```bash
  oc create secret generic frontend-credential \
  --from-file=tls.key=certs/frontend.key \
  --from-file=tls.crt=certs/frontend.crt \
  --from-file=ca.crt=certs/acme.com.crt \
  -n control-plane
  ```
  
- Update Gateway with TLS mode SIMPLE
- Test with cURL

### Configure Gateway with mTLS
WIP

## Interactive Command Line setup
[setup.sh](setup.sh) will automate create control plane, data plane, deploy applications and configured mTLS for all communications including ingress. 


<!-- Secure Gateways is enabled by default for OpenShift Service Mesh 2.0 (Istio 1.6) -->

```bash
./setup.sh
# Following instruction provided by bash script
```

To cleanup both control plane and data plane

```bash
./cleanup.sh
```


<!-- ## Load Test with JMeter

JMeter with preconfigred truststore and keystore JKS already prepared.

Remark: Edit [run-test.sh](load-test/run-test.sh) to specified based installation path of JMeter to environment variable JMETER_BASE_PATH

```
cd load-test
./run-test.sh $$<hostname - without https> <threads> <loops>
# Example
# ./run-test.sh frontend-data-plane.apps.example.com 200 500
```

Sample reports generated from testresult.jtl

  - Aggregate report
  
    ![](images/jmeter-aggregate-report.png)

  - Summary report

    ![](images/jmeter-summary-report.png)

Graph in Kiali Console

![](images/sample-kiali.png)

You can check Grafana in Control Plane project workloads

![](images/sample-grafana.png) -->


<!-- ## Pod Liveness & Readiness

```bash
oc rollout pause deployment/backend-v1 
oc set probe deployment/backend-v1 --readiness --get-url=http://:8080/health/ready --failure-threshold=1 --initial-delay-seconds=5--period-seconds=5 
oc set probe deployment/backend-v1 --liveness --get-url=http://:8080/health/live --failure-threshold=1 --initial-delay-seconds=5 --period-seconds=5 
oc rollout resume deployment/backend-v1 
oc patch deployment/backend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/rewriteAppHTTPProbers":"true"}}}}}'
``` -->

<!-- Kiali
oc rollout pause deployment/backend-v1 
oc patch deployment/backend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"kiali.io/runtimes":"quarkus"}}}}}'
oc patch deployment/backend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true"}}}}}'
oc patch deployment/backend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/port":"8080"}}}}}'
oc patch deployment/backend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scheme":"http"}}}}}'
oc patch deployment/backend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/path":"/metrics"}}}}}'
oc rollout resume deployment/backend-v1  -->
