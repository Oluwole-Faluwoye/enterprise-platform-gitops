# Grafana Dashboard Catalog

This directory contains the engineering documentation for every Grafana dashboard deployed to the Enterprise Platform.

Each dashboard is fully managed through GitOps using Helm and Argo CD.

Every dashboard has:

- Design document
- Dashboard JSON
- Metadata
- Operational runbook
- PromQL explanation
- Troubleshooting guide

Dashboard Categories

Infrastructure

- Cluster Overview
- Nodes
- Storage
- Networking

Kubernetes

- Pods
- Deployments
- StatefulSets
- DaemonSets

Platform

- Prometheus
- Alertmanager
- Loki
- Argo CD
- Jenkins

Applications

- Auth Service
- Spring Boot
- JVM
- HTTP

Business

- API Usage
- Error Rate
- Availability