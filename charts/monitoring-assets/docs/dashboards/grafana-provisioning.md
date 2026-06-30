# Grafana Provisioning

## Overview

Grafana is the visualization layer of the Enterprise Platform Observability Stack.

Rather than configuring Grafana manually through the web interface, every dashboard, datasource, provider, and folder is provisioned automatically from Git using Helm and Argo CD.

This ensures that the monitoring platform is fully reproducible, version-controlled, and consistent across every Kubernetes environment.

---

# Objectives

The Grafana provisioning architecture was designed to achieve the following goals:

- Fully automated deployments
- GitOps-driven configuration
- Eliminate manual dashboard imports
- Prevent configuration drift
- Standardize monitoring across environments
- Enable version control for every dashboard
- Support scalable enterprise operations

---

# Why We Do Not Configure Grafana Manually

Many organizations begin by importing dashboards directly through the Grafana UI.

Although this approach is simple initially, it introduces several operational problems.

## Manual configuration causes

- dashboards that exist only inside Grafana
- configuration drift between environments
- accidental dashboard edits
- dashboards being lost after redeployment
- no change history
- difficult disaster recovery
- inconsistent monitoring across clusters

For production systems, this approach does not scale.

Everything must be reproducible.

---

# GitOps Provisioning Workflow

The Enterprise Platform follows a GitOps deployment model.

```
Developer

↓

Commit Dashboard JSON

↓

GitHub Repository

↓

Argo CD

↓

Helm Chart

↓

ConfigMaps

↓

Grafana Sidecar

↓

Dashboard Automatically Available
```

No engineer logs into Grafana to import dashboards.

Git remains the single source of truth.

---

# Grafana Provisioning Architecture

```
monitoring-assets

│

├── grafana

│   ├── dashboards

│   ├── datasources

│   ├── folders

│   └── providers

│

└── templates
```

Each directory represents one logical responsibility.

---

# Dashboards

Location

```
grafana/dashboards/
```

Contains every dashboard as JSON.

Examples

```
Cluster Overview

Nodes

Storage

Networking

Prometheus

Loki

Jenkins

ArgoCD

Auth Service
```

Dashboards are committed directly into Git.

Helm automatically packages them into ConfigMaps.

---

# Datasources

Location

```
grafana/datasources/
```

Contains datasource definitions.

Current datasources include

- Prometheus
- Loki

Future datasources may include

- Tempo
- Pyroscope
- CloudWatch
- OpenSearch
- Jaeger

No dashboard should reference datasource names directly.

Every datasource uses a stable UID.

---

# Why Datasource UIDs?

Instead of

```
Prometheus
```

dashboards reference

```
uid: prometheus
```

Reasons

- Names may change
- UIDs remain constant
- Dashboards become portable
- Easier migration between environments

---

# Dashboard Providers

Location

```
grafana/providers/
```

Dashboard Providers instruct Grafana where dashboards are stored.

Current configuration

```
/var/lib/grafana/dashboards
```

Grafana continuously watches this directory for changes.

Whenever Argo CD updates a ConfigMap, Grafana automatically reloads the dashboard.

No restart is required.

---

# Folder Organization

Dashboards are grouped into logical folders.

Current categories

Infrastructure

Kubernetes

Platform

Applications

Business

This organization improves navigation and reduces operational complexity as the number of dashboards grows.

---

# Helm Templates

The monitoring-assets Helm chart contains generic templates.

Instead of creating one ConfigMap for every dashboard manually, Helm automatically iterates over every JSON file.

Example

```
grafana/dashboards/

↓

Helm Files.Glob()

↓

ConfigMaps

↓

Grafana
```

Adding a dashboard requires only one action.

```
Copy dashboard JSON

↓

Commit

↓

Push

↓

Argo CD Sync

↓

Dashboard Available
```

No Helm template modifications are required.

---

# Why ConfigMaps?

Grafana's sidecar container watches ConfigMaps with the label

```
grafana_dashboard=1
```

Whenever a ConfigMap changes, Grafana automatically reloads the dashboard.

Advantages

- No manual imports
- Automatic synchronization
- Native Kubernetes integration
- GitOps compatible

---

# Enterprise Benefits

The provisioning model provides several operational advantages.

## Version Control

Every change is tracked through Git.

Dashboard history is preserved.

Code reviews are possible.

Rollback is straightforward.

---

## Disaster Recovery

A complete Grafana instance can be recreated simply by redeploying the Helm chart.

No manual exports or backups of dashboards are required.

---

## Environment Consistency

Development

Testing

Production

all receive identical dashboard definitions.

This eliminates environment drift.

---

## Scalability

As new services are introduced, dashboards can be added without modifying Helm templates.

The deployment workflow remains identical regardless of whether the platform contains

- 5 dashboards
- 50 dashboards
- 500 dashboards

---

# Operational Workflow

The recommended workflow for creating a new dashboard is

```
Design Dashboard

↓

Export JSON

↓

Store under grafana/dashboards/

↓

Commit

↓

Push

↓

Argo CD Sync

↓

Grafana loads automatically
```

This process ensures every dashboard is reviewed, version-controlled, and reproducible.

---

# Best Practices

The Enterprise Platform follows the following principles.

- Never create dashboards manually in production.
- Never edit dashboards directly in Grafana.
- Store every dashboard in Git.
- Use stable datasource UIDs.
- Group dashboards into logical folders.
- Use generic Helm templates instead of one ConfigMap per dashboard.
- Allow Argo CD to remain the deployment controller.
- Keep Git as the single source of truth.

---

# Summary

Grafana provisioning is fully automated using Helm and Argo CD.

Every dashboard, datasource, folder, and provider is stored in Git and deployed declaratively into Kubernetes.

This GitOps approach provides repeatability, consistency, disaster recovery, auditability, and scalability, making it suitable for enterprise production environments where infrastructure and observability must be managed as code.