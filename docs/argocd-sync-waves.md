# ArgoCD Sync Waves

## Purpose

ArgoCD Sync Waves control the order in which applications and resources are deployed. By default, ArgoCD deploys everything simultaneously, which can cause dependency issues when one component requires another to exist first.

## How It Works

ArgoCD deploys resources in ascending order:

* Lower numbers deploy first
* Higher numbers deploy later

Example:

sync-wave: -1 → Deploy first

sync-wave: 0 → Deploy next

sync-wave: 1 → Deploy after wave 0

sync-wave: 2 → Deploy after wave 1

## Why We Use Sync Waves

Some resources depend on others being available before they can start successfully.

Example:

StorageClass (gp3)
↓
Persistent Volume Claims (PVCs)
↓
EBS Volumes
↓
Prometheus / Grafana / Loki

If Prometheus is deployed before the StorageClass exists, its PVCs may remain in Pending state and pods may fail to start.

## Sync Wave Design for This Project

| Sync Wave | Component              | Reason                                                                                             |
| --------- | ---------------------- | -------------------------------------------------------------------------------------------------- |
| -1        | Storage (StorageClass) | Must exist before PVCs are created                                                                 |
| 0         | Prometheus Stack       | Installs Prometheus, Grafana, AlertManager, Node Exporter, kube-state-metrics, and monitoring CRDs |
| 1         | Loki                   | Requires storage and monitoring platform                                                           |
| 2         | Promtail               | Ships logs to Loki                                                                                 |
| 3         | Monitoring Alerts      | Depends on Prometheus Operator CRDs                                                                |
| 4         | Auth Service           | Application is onboarded after observability platform is operational                               |

## Example Annotation

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

## Enterprise Benefit

Sync Waves ensure predictable platform bootstrapping and eliminate deployment race conditions during automated cluster creation.

Recommended deployment flow:

Infrastructure
↓
Storage
↓
Observability Platform
↓
Shared Services
↓
Applications

This approach improves reliability, reduces startup failures, and follows enterprise GitOps deployment practices.

---

# Enterprise Example (Large-Scale Platform)

A typical enterprise Kubernetes platform may use many sync waves to ensure foundational services are deployed before applications.

| Sync Wave | Component Category                                      |
| --------- | ------------------------------------------------------- |
| -5        | Namespaces                                              |
| -4        | Storage Classes                                         |
| -3        | Cert Manager                                            |
| -2        | Ingress Controllers (NGINX / ALB Controller)            |
| -1        | External Secrets / Vault Integration                    |
| 0         | Monitoring Platform (Prometheus, Grafana, AlertManager) |
| 1         | Logging Platform (Loki)                                 |
| 2         | Log Collectors (Promtail / Fluent Bit)                  |
| 3         | Security Tooling (Falco, Kyverno, Gatekeeper)           |
| 4         | Shared Platform Services                                |
| 5         | Databases and Stateful Services                         |
| 6         | Core Business Applications                              |
| 7         | Batch Jobs and Scheduled Workloads                      |

Example Enterprise Deployment Flow:

Terraform
↓
AWS Infrastructure
↓
EKS Cluster
↓
ArgoCD
↓
Namespaces
↓
Storage Classes
↓
Ingress Controllers
↓
External Secrets
↓
Monitoring Stack
↓
Logging Stack
↓
Security Platform
↓
Shared Services
↓
Microservices
↓
Batch Jobs

By organizing deployments into sync waves, platform teams can rebuild an entire Kubernetes environment from scratch with a single Terraform Apply and allow ArgoCD to safely deploy all dependent services in the correct order.
