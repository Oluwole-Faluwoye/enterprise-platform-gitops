# Cluster Overview Dashboard Design Specification

> **Document ID:** OBS-DB-001 **Dashboard:** Cluster Overview
> **Category:** Infrastructure **Owner:** Platform Engineering Team

## 1. Purpose

The Cluster Overview dashboard is the primary operational dashboard for
the Enterprise Platform. Every production investigation begins here
before engineers drill down into Kubernetes, platform, application, and
business dashboards.

### Objectives

-   Determine overall cluster health
-   Verify worker node availability
-   Detect resource exhaustion
-   Identify scheduling problems
-   Provide a single operational landing page

## 2. Architecture

``` text
Git -> Argo CD -> Helm -> ConfigMap -> Grafana Sidecar -> Dashboard Provider -> Grafana
```

Git is the single source of truth. Dashboards are never edited manually
in Grafana.

## 3. Dashboard Layout

1.  Cluster Health
2.  Nodes
3.  CPU & Memory
4.  Network
5.  Storage
6.  Pods & Workloads
7.  Top Consumers
8.  Active Alerts

## 4. Data Sources

### Prometheus

Stores metrics.

### kube-state-metrics

Exposes Kubernetes object metrics.

### Node Exporter

Exposes operating system metrics.

### cAdvisor

Exposes container resource metrics.

## 5. Core Panels

### Cluster Status

Answers whether Kubernetes is healthy.

### Nodes Ready

Shows ready worker nodes.

### CPU Utilization

Primary metric: `node_cpu_seconds_total`

Healthy: \<60%

Warning: 60--80%

Critical: \>90%

### Memory Utilization

Primary metrics:

-   node_memory_MemAvailable_bytes
-   node_memory_MemTotal_bytes

### Running Pods

Tracks operational workloads.

### Pending Pods

Indicates scheduling issues.

Typical causes:

-   insufficient CPU
-   insufficient memory
-   PVC pending
-   node taints
-   pod limits

### Restart Count

Detects unstable workloads.

### Top CPU Pods

Used during incident investigations.

### Top Memory Pods

Detects memory leaks.

## 6. Example PromQL

CPU

``` promql
100 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100
```

Memory

``` promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

Running Pods

``` promql
count(kube_pod_status_phase{phase="Running"})
```

Pending Pods

``` promql
count(kube_pod_status_phase{phase="Pending"})
```

## 7. Investigation Workflow

1.  Cluster Overview
2.  Nodes
3.  Kubernetes
4.  Platform
5.  Application
6.  Logs
7.  Business

## 8. Alert Flow

Prometheus Rule -\> Alertmanager -\> Notification -\> Engineer

## 9. Troubleshooting

High CPU: - Identify top CPU pods - Check HPA - Review deployments

Pending Pods: - Scheduler events - PVC status - Node capacity

High Memory: - OOMKilled events - Heap usage - Limits

## 10. Best Practices

-   Git is the source of truth.
-   Never edit dashboards in the Grafana UI.
-   Use datasource UIDs.
-   Version every dashboard.
-   Review dashboard changes via pull requests.

## 11. Scaling

As clusters grow: - Introduce recording rules - Use remote write -
Consider Thanos - Organize dashboards by category

## 12. Interview Talking Points

The dashboard is the operational landing page. It is provisioned
automatically using Helm, Argo CD, ConfigMaps, Grafana sidecars, and
dashboard providers. The design minimizes manual work and ensures
consistent environments.

## 13. Future Improvements

-   SLO dashboards
-   Error budgets
-   Cost dashboards
-   Multi-cluster monitoring
-   Tempo tracing

## References

-   Kubernetes
-   Prometheus
-   Grafana
-   kube-state-metrics
-   Node Exporter
-   cAdvisor
