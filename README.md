# Mutual TLS ingress gateway with Istio

## OpenShift Service 1.1 
Secure Gateways is disabled by default for OpenShift Service Mesh 1.1 (Istio 1.4) then ingressgateway pod need to be restarted after gateway is created.

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
