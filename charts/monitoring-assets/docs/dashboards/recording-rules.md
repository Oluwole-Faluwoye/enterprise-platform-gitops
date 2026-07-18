# Recording Rules

## Overview

Recording Rules are one of the most important performance optimization features provided by Prometheus.

Rather than executing expensive PromQL queries every time a dashboard is opened or an alert is evaluated, Prometheus periodically evaluates predefined expressions and stores the results as new time series.

These precomputed metrics are called **Recording Rules**.

Within the Enterprise Platform, Recording Rules form the foundation of the observability architecture by providing fast, reusable, and standardized metrics that power Grafana dashboards, Alertmanager alerts, Service Level Objectives (SLOs), and operational reporting.

---

# Objectives

The Recording Rules implementation was designed to achieve the following objectives:

- Improve Grafana dashboard performance
- Reduce Prometheus query execution time
- Standardize metric calculations
- Eliminate duplicate PromQL expressions
- Provide reusable metrics for dashboards and alerts
- Improve scalability as the platform grows

---

# What Are Recording Rules?

A Recording Rule is a Prometheus rule that periodically evaluates a PromQL expression and stores the result as a new metric.

Instead of repeatedly calculating the same expression whenever it is requested, Prometheus performs the calculation once at a fixed interval and saves the output.

For example, instead of repeatedly executing:

```promql
rate(http_server_requests_seconds_count[5m])
```

Prometheus can evaluate the query every 30 seconds and store the result as:

```text
app:http_requests:rate5m
```

Dashboards and alerts then query the new metric directly.

This significantly reduces the computational cost of querying Prometheus.

---

# Why Recording Rules Are Important

Without Recording Rules, every Grafana panel and every alert executes its own PromQL query.

As the platform grows, this becomes increasingly expensive.

Example:

```
15 Dashboards

↓

20 Engineers Viewing Dashboards

↓

Hundreds of PromQL Queries

↓

High Prometheus CPU Usage

↓

Slow Dashboard Loading
```

With Recording Rules:

```
Prometheus

↓

Recording Rule

↓

Precomputed Metric

↓

Grafana Dashboard

↓

Instant Query Results
```

Instead of evaluating complex expressions hundreds of times, Prometheus evaluates them once and stores the result.

---

# Benefits of Recording Rules

## Faster Grafana Dashboards

Grafana panels query precomputed metrics rather than executing complex PromQL expressions.

This results in:

- Faster dashboard loading
- Lower latency
- Better user experience
- Reduced query complexity

---

## Reduced CPU Load on Prometheus

Prometheus evaluates each Recording Rule at a configured interval.

Subsequent dashboard and alert queries use the stored metric instead of recalculating the original expression.

Benefits include:

- Lower CPU utilization
- Lower memory consumption
- Improved Prometheus responsiveness
- Better scalability

---

## Reusable Metrics

Recording Rules create standardized metrics that can be reused across the platform.

For example:

```
app:http_requests:rate5m
```

can be used by:

- Grafana dashboards
- Alertmanager
- SLO calculations
- Capacity planning
- Operational reports

A metric is calculated once and consumed by multiple systems.

---

## Consistent Calculations

Without Recording Rules, different engineers may write slightly different PromQL expressions for the same metric.

For example:

Engineer A

```promql
rate(http_server_requests_seconds_count[5m])
```

Engineer B

```promql
sum(rate(http_server_requests_seconds_count[5m]))
```

These expressions may produce different results.

Recording Rules eliminate this inconsistency by providing a single, standardized metric that every dashboard and alert references.

---

# How Recording Rules Fit into the Platform

The Enterprise Platform follows the architecture below:

```
Application

↓

Micrometer

↓

Prometheus

↓

Recording Rules

↓

Grafana Dashboards
        │
        │
        ▼
Alertmanager

↓

Notifications
```

Application metrics are collected by Prometheus.

Recording Rules transform raw metrics into optimized metrics.

These optimized metrics are then consumed by dashboards and alerts.

This architecture reduces duplication and improves overall platform performance.

---

# Rule Organization

Recording Rules are organized into logical groups based on ownership and purpose.

Grouping related rules together improves readability, maintainability, and troubleshooting.

---

## Infrastructure Rules

Infrastructure rules monitor the underlying Kubernetes worker nodes and supporting infrastructure.

Examples include:

- CPU utilization
- Memory utilization
- Filesystem utilization
- Disk usage
- Network throughput

These metrics are primarily consumed by:

- Cluster Overview Dashboard
- Node Dashboard
- Capacity Planning Dashboard

---

## Kubernetes Rules

Kubernetes rules summarize the health and state of workloads running within the cluster.

Examples include:

- Running Pods
- Pending Pods
- Ready Nodes
- Deployment availability
- Namespace statistics

These rules support dashboards focused on Kubernetes operations.

---

## Application Rules

Application rules are generated from metrics exposed by Spring Boot applications through Micrometer.

Examples include:

- HTTP request rate
- Error rate
- Request latency
- Throughput
- Response time

These metrics support application dashboards, SLOs, and service health monitoring.

---

# Naming Convention

Recording Rules follow a consistent naming convention.

Examples:

```
node:cpu_utilisation:avg5m

cluster:pods:running

app:http_requests:rate5m

app:error_rate:5m
```

Benefits include:

- Easy identification
- Consistent naming
- Improved readability
- Better dashboard organization

Metric names should clearly describe:

- Resource
- Metric
- Aggregation
- Time interval (if applicable)

---

# Best Practices

The Enterprise Platform follows the following best practices when creating Recording Rules.

## Keep Rules Focused

Each Recording Rule should calculate a single, well-defined metric.

Avoid combining unrelated calculations within the same rule.

---

## Use Descriptive Metric Names

Metric names should clearly communicate their purpose.

Avoid vague names such as:

```
cpu_usage
```

Prefer descriptive names such as:

```
node:cpu_utilisation:avg5m
```

---

## Group Rules by Domain

Recording Rules should be organized into logical groups.

Examples include:

- Infrastructure
- Kubernetes
- Applications
- Business Metrics

This simplifies maintenance and ownership.

---

## Reuse Recording Rules

Dashboards and alerts should reference Recording Rules whenever possible.

Avoid repeating raw PromQL expressions throughout the platform.

Benefits include:

- Improved consistency
- Reduced Prometheus load
- Easier maintenance
- Simplified dashboard development

---

## Optimize Expensive Queries

Recording Rules should primarily target PromQL expressions that are computationally expensive.

Examples include:

- rate()
- histogram_quantile()
- sum by()
- avg by()
- Complex aggregations

Frequently executed queries benefit the most from precomputation.

---

# Operational Workflow

The recommended workflow for introducing a new Recording Rule is:

```
Identify Expensive Query

↓

Create Recording Rule

↓

Commit to Git

↓

Argo CD Synchronizes

↓

Prometheus Loads Rule

↓

Dashboards Consume New Metric

↓

Alerts Reuse Same Metric
```

This workflow ensures that every optimized metric is version-controlled, reviewed, and automatically deployed.

---

# Validation

After Argo CD synchronizes the Monitoring Assets chart, verify that the Recording Rules have been deployed successfully.

List all PrometheusRule resources:

```bash
kubectl get prometheusrules -n monitoring
```

Expected output:

```
NAME
enterprise-recording-rules
```

Inspect the Recording Rule resource:

```bash
kubectl describe prometheusrule enterprise-recording-rules -n monitoring
```

Verify that the rule groups are present:

- infrastructure.rules
- kubernetes.rules
- application.rules

Confirm that Prometheus has loaded the rules without errors.

Next, port-forward the Prometheus service:

```bash
kubectl port-forward svc/prometheus-stack-kube-prom-prometheus -n monitoring 9090:9090
```

Open:

```
http://localhost:9090
```

Navigate to **Graph** and execute one of the newly created metrics:

```promql
cluster:pods:running
```

or

```promql
node:cpu_utilisation:avg5m
```

If the queries return data, the Recording Rules have been evaluated successfully.

---

# Enterprise Benefits

Implementing Recording Rules provides several long-term operational advantages.

- Faster Grafana dashboards
- Lower Prometheus resource consumption
- Consistent metric calculations
- Simplified alert development
- Reusable metrics across the platform
- Improved scalability
- Better maintainability
- Easier onboarding for new engineers
- Reduced duplication of PromQL expressions

As the Enterprise Platform grows to include additional microservices, dashboards, and environments, Recording Rules ensure that the observability platform remains performant, maintainable, and scalable while adhering to GitOps and Infrastructure-as-Code principles.

---

# Summary

Recording Rules are a core component of the Enterprise Platform Observability Architecture.

They transform expensive PromQL expressions into reusable metrics that improve dashboard responsiveness, reduce Prometheus workload, standardize calculations, and provide a consistent foundation for dashboards, alerts, and Service Level Objectives.

By managing Recording Rules through Helm and Argo CD, the platform ensures that every optimization is version-controlled, repeatable, and automatically deployed, aligning with enterprise GitOps best practices.