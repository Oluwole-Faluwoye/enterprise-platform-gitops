ArgoCD

Responsibility

ArgoCD reconciles Kubernetes workloads from Git.

Terraform does not deploy normal application Kubernetes changes
directly.

Canonical application model

GitOps repository
      ↓
ArgoCD Application
      ↓
Helm
      ↓
Kubernetes

Platform applications validated

The live DEV validation included:

ArgoCD

AWS Load Balancer Controller

ExternalDNS

External Secrets Operator

cert-manager

Prometheus

Alertmanager

Grafana

Loki

Promtail

kube-state-metrics

AWS EBS CSI driver

Auth-service

The auth-service ArgoCD Application deploys into:

identity

and manages the Spring Boot workload.