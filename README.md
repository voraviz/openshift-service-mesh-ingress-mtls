# Mutual TLS ingress gateway with Istio

[setup.sh](ossm1.1/setup.sh) will automate create control plane, data plane, deploy applications and configured mTLS for all communiations but it does not install Operators requried by OpenShift Service Mesh. You need to install following Operators from OperatorHub.

- ElasticSearch
- Jaeger
- Kiali
- OpenShift Service Mesh

## OpenShift Service 1.1 
For control plane create with OpenShift Service Mesh 1.1. Secure Gateways is disabled by default then ingressgateway pod need to be restarted after gateway is created. This behavior is improved with Secure Gateway that restart ingressgateway is not required.

```bash
cd ossm1.1
./setup.sh
```

## OpenShift Service Mesh 2.x
Secure Gateways is enabled by default for OpenShift Service Mesh 2.0 (Istio 1.6)

```bash
cd ossm2
./setup.sh
```

## Load Test with JMeter

JMeter JMX with preconfigred truststore and keystore JKS already prepared.

Remark: Edit [run-test.sh](load-test/run-test.sh) to specified based installation path of JMeter to environment variable JMETER_BASE_PATH

```
cd load-test
./run-test.sh <hostname - without https> <threads> <loops>
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

![](images/sample-grafana.png)


Liveness & Readiness
oc rollout pause deployment/backend-v1 
oc set probe deployment/backend-v1 --readiness --get-url=http://:8080/health/ready --failure-threshold=1 --initial-delay-seconds=5--period-seconds=5 
oc set probe deployment/backend-v1 --liveness --get-url=http://:8080/health/ready --failure-threshold=1 --initial-delay-seconds=5 --period-seconds=5 
oc rollout resume deployment/backend-v1 
oc patch deployment/backend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/rewriteAppHTTPProbers":"true"}}}}}'


Kiali
oc rollout pause deployment/backend-v1 
oc patch deployment/backend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"kiali.io/runtimes":"quarkus"}}}}}'
oc patch deployment/backend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scrape":"true"}}}}}'
oc patch deployment/backend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/port":"8080"}}}}}'
oc patch deployment/backend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/scheme":"http"}}}}}'
oc patch deployment/backend-v1 -p '{"spec":{"template":{"metadata":{"annotations":{"prometheus.io/path":"/metrics"}}}}}'
oc rollout resume deployment/backend-v1 