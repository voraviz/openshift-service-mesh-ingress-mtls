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

![](images/sample-kiali.png)
