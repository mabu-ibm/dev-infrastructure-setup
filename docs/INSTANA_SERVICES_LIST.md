# Instana Services List

**Generated:** 2026-03-31  
**Time Range:** Last 1 hour  
**Total Services Found:** 50+

## Summary by Namespace

### 1. otel-demo (OpenTelemetry Demo Application)
- **accounting-7c87bdf584-srtcb** - Accounting service
- **ad-7458b948bc-57p97** - Advertisement service
- **cart-684bc6dd84-bhn7n** - Shopping cart service
- **checkout-d6b965564-x8tp4** - Checkout service
- **currency-5cb5b5b9b9-7v95f** - Currency conversion service
- **email-56dd7896b9-gqjqw** - Email service
- **flagd-58f8467b8b-v2xbd** - Feature flag daemon (2 containers)
- **fraud-detection-66974cdb8d-vrtft** - Fraud detection service
- **frontend-5c888458c-jh5jb** - Frontend application
- **frontend-proxy-7bb6598d99-q2ntv** - Frontend proxy
- **grafana-7f6c4fddf5-pcv79** - Grafana monitoring (4 containers)
- **image-provider-846bb99685-c54hw** - Image provider service
- **kafka-0** - Kafka message broker
- **load-generator-6d4c8c9f9d-xxxxx** - Load generation service
- **payment-xxxxx** - Payment processing service
- **product-catalog-xxxxx** - Product catalog service
- **quote-xxxxx** - Quote service
- **recommendation-xxxxx** - Recommendation engine
- **shipping-xxxxx** - Shipping service

### 2. kube-system (Kubernetes System Services)
- **calico-kube-controllers-868cbf9cc-dbzlx** - Calico network controller
- **calico-node-44kc2** - Calico network node agent
- **calico-node-klrsw** - Calico network node agent
- **calico-node-m2l69** - Calico network node agent
- **coredns-5688667fd4-jnx7h** - CoreDNS service
- **coredns-87946dcb5-fl4g7** - CoreDNS service
- **coredns-87946dcb5-jmhhc** - CoreDNS service
- **etcd-master-node** - etcd key-value store

### 3. bum (Bundesmessenger - Matrix Messaging Platform)
- **demo1-bundesmessenger-bdb474898-vgrpz** - Main messenger service
- **demo1-confighub-nginx-7bb44c4fd8-f67xk** - Configuration hub with nginx
- **demo1-generic-worker-0** - Generic worker instance 1
- **demo1-generic-worker-1** - Generic worker instance 2
- **demo1-maspostgresql-0** - PostgreSQL for Matrix Authentication Service
- **demo1-matrix-authentication-service-0** - Matrix authentication service
- **demo1-matrix-content-scanner-0** - Content scanning service
- **demo1-media-repository-0** - Media file repository
- **demo1-postgresql-0** - Main PostgreSQL database
- **demo1-redis-0** - Redis cache
- **demo1-schadcodescanner-0** - Malware/malicious code scanner (2 containers)
- **demo1-signingkey-job-hfp4t** - Signing key generation job (2 containers)
- **demo1-synapse-admin-8b49db8f-j9sh6** - Synapse admin interface
- **demo1-webclient-5cb885f854-4jqnp** - Web client application
- **demo1-wellknown-nginx-6d4b7c9f54-2cr4g** - Well-known endpoint nginx

### 4. cert-manager (Certificate Management)
- **cert-manager-7dfcddcdd5-f72cp** - Certificate manager controller
- **cert-manager-cainjector-58d74bf4f5-t76cl** - CA injector
- **cert-manager-webhook-6db4c65b5d-tvx2t** - Webhook service

### 5. metallb-system (Load Balancer)
- **controller-74b6dc8f85-2c496** - MetalLB controller instance 1
- **controller-74b6dc8f85-6zhr7** - MetalLB controller instance 2

### 6. ingress-nginx (Ingress Controller)
- **ingress-nginx-controller-7c64b86f6d-s8lvx** - NGINX ingress controller

### 7. instana-agent (Monitoring)
- **instana-agent-5hsc7** - Instana agent on node 1
- **instana-agent-622gw** - Instana agent on node 2
- **instana-agent-6kkft** - Instana agent on node 3
- **instana-agent-controller-manager-5bbbd7dddc-bng8p** - Agent controller manager

### 8. default (Test Services)
- **echo-service1** - Echo test service 1
- **echo-service2** - Echo test service 2
- **echo-service3** - Echo test service 3
- **echo-service4** - Echo test service 4
- **echo-service5** - Echo test service 5

## Service Categories

### Application Services (otel-demo)
Microservices-based e-commerce demo application with:
- Frontend services (UI, proxy)
- Backend services (cart, checkout, payment, shipping)
- Support services (email, currency, fraud detection)
- Data services (product catalog, recommendations)
- Infrastructure (Kafka, Grafana monitoring)

### Messaging Platform (bum)
Enterprise Matrix-based messaging platform with:
- Core messaging services
- Authentication and security
- Media handling and content scanning
- Database and caching layers
- Admin and web interfaces

### Infrastructure Services
- **Networking:** Calico CNI, MetalLB load balancer, NGINX ingress
- **DNS:** CoreDNS for service discovery
- **Storage:** etcd for cluster state
- **Security:** cert-manager for TLS certificates
- **Monitoring:** Instana agents across all nodes

## Key Observations

1. **Multi-Container Pods:**
   - grafana: 4 containers (monitoring stack)
   - flagd: 2 containers (feature flags)
   - demo1-schadcodescanner: 2 containers (malware scanning)
   - demo1-signingkey-job: 2 containers (key generation)

2. **High Availability:**
   - Multiple CoreDNS instances (3)
   - Multiple Calico nodes (3)
   - Multiple MetalLB controllers (2)
   - Instana agents on all nodes (3+)

3. **Namespaces:**
   - 8 distinct namespaces
   - Clear separation of concerns
   - Proper isolation between applications

4. **Service Types:**
   - StatefulSets (databases, message queues)
   - Deployments (application services)
   - DaemonSets (network agents, monitoring)
   - Jobs (one-time tasks)

## Next Steps

To get more detailed information about specific services:

```bash
# Get service metrics
kubectl top pods -n otel-demo
kubectl top pods -n bum

# Check service health
kubectl get pods -n otel-demo
kubectl describe pod <pod-name> -n <namespace>

# View service logs
kubectl logs <pod-name> -n <namespace>
```

## Instana Monitoring

All services are monitored by Instana agents providing:
- Real-time performance metrics
- Distributed tracing
- Application dependency mapping
- Automatic service discovery
- Health and availability monitoring