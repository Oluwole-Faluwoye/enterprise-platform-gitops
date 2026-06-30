# Observability Architecture

**Project:** Enterprise Platform Engineering Project

**Repository:** enterprise-platform-gitops

**Document Version:** 1.0

---

# Table of Contents

1. Introduction
2. What is Observability?
3. The Three Pillars of Observability
4. Why Traditional Monitoring Is Not Enough
5. Platform Architecture
6. Observability Components
7. Data Flow
8. Kubernetes Monitoring Architecture
9. Component Responsibilities
10. Prometheus Deep Dive
11. Grafana Deep Dive
12. Loki Deep Dive
13. Promtail Deep Dive
14. Alertmanager Deep Dive
15. ServiceMonitor Deep Dive
16. Dashboard Strategy
17. Alert Strategy
18. Scaling Strategy
19. Disaster Recovery
20. Enterprise Best Practices

---

# 1. Introduction

Observability is the ability to understand the internal state of a system by examining the data it produces.

Unlike traditional monitoring, observability enables engineers to investigate unknown failures, identify performance bottlenecks, understand distributed systems, and diagnose production incidents.

For a Kubernetes platform, observability consists of three major data types:

- Metrics
- Logs
- Traces

This project currently implements metrics and centralized logging. Distributed tracing will be introduced in a future enhancement using OpenTelemetry.

---

# 2. What is Observability?

Monitoring answers predefined questions.

Examples:

- Is CPU above 80%?
- Is memory usage increasing?
- Is a pod restarting?

Observability allows engineers to answer questions that were never anticipated during development.

Examples:

- Why did requests suddenly increase?
- Why are only users in one region affected?
- Which deployment introduced latency?
- Which pod generated the error?

Observability provides the information required to answer these questions.

---

# 3. The Three Pillars of Observability

## Metrics

Metrics are numerical measurements collected over time.

Examples:

- CPU usage
- Memory usage
- HTTP requests
- JVM Heap
- Pod count

Collected by:

Prometheus

---

## Logs

Logs are timestamped records of events.

Examples:

Application started

Database timeout

Authentication failed

API returned HTTP 500

Collected by:

Promtail

Stored by:

Loki

---

## Traces

Traces follow a request through multiple services.

Example:

Client

↓

API Gateway

↓

Authentication Service

↓

User Service

↓

Database

↓

Response

Future implementation:

OpenTelemetry

Jaeger

---

# 4. Why Traditional Monitoring Is Not Enough

Traditional monitoring only answers expected questions.

Example:

CPU > 80%

Memory > 90%

Disk Full

Modern cloud platforms require visibility into:

Container scheduling

Kubernetes health

Application behavior

Infrastructure

Logs

Alerts

Distributed systems

---

# 5. Platform Architecture

```
                         Kubernetes Cluster

                                │

         ┌──────────────────────┼──────────────────────┐

         │                      │                      │

    Application            Kubernetes           Infrastructure

         │                      │                      │

         └───────────────Metrics───────────────────────┘

                                │

                        ServiceMonitor

                                │

                           Prometheus

                                │

             ┌──────────────────┴──────────────────┐

             │                                     │

         Alertmanager                          Grafana

                                                   │

                                           Dashboards

--------------------------------------------------------------

Application Logs

↓

stdout

↓

Promtail

↓

Loki

↓

Grafana Explore

```

---

# 6. Observability Components

Current stack consists of:

- Prometheus
- Grafana
- Loki
- Promtail
- kube-state-metrics
- Node Exporter
- Alertmanager
- Prometheus Operator

Each component has a single responsibility.

This separation follows the Unix philosophy:

Do one thing well.

---

# 7. Data Flow

## Metrics

Spring Boot

↓

Micrometer

↓

/actuator/prometheus

↓

ServiceMonitor

↓

Prometheus

↓

Grafana Dashboard

---

## Logs

Container stdout

↓

Promtail

↓

Loki

↓

Grafana Explore

---

## Alerts

Prometheus Rule

↓

Alert Evaluation

↓

Alertmanager

↓

Email / Slack / Teams

---

# 8. Kubernetes Monitoring Architecture

The monitoring stack is deployed using the kube-prometheus-stack Helm chart.

This chart installs multiple Kubernetes resources including:

Deployments

DaemonSets

StatefulSets

ConfigMaps

Secrets

ServiceAccounts

CRDs

Each resource contributes to the observability platform.

---

# 9. Component Responsibilities

## Prometheus

Responsibilities

- Scrape metrics
- Store metrics
- Execute PromQL
- Evaluate alert rules

---

## Grafana

Responsibilities

- Visualization
- Dashboards
- Correlation
- Alert display

Grafana does not collect metrics.

It only visualizes data.

---

## Loki

Responsibilities

- Store logs
- Index labels
- Query logs

Unlike Elasticsearch, Loki indexes labels rather than log contents.

This dramatically reduces infrastructure cost.

---

## Promtail

Responsibilities

- Watch container logs
- Add Kubernetes labels
- Push logs to Loki

Every node runs exactly one Promtail instance.

---

## Alertmanager

Responsibilities

- Group alerts
- Route alerts
- Silence alerts
- Deduplicate alerts
- Send notifications

---

## kube-state-metrics

Reads Kubernetes objects.

Examples:

Deployments

Pods

ReplicaSets

StatefulSets

Namespaces

PVCs

Nodes

It does NOT monitor CPU or memory.

It monitors Kubernetes object state.

---

## Node Exporter

Runs on every node.

Collects:

CPU

RAM

Filesystem

Disk

Network

Kernel

---

## Prometheus Operator

Automates Prometheus management.

Instead of editing Prometheus configuration manually, engineers define Kubernetes resources such as:

ServiceMonitor

PodMonitor

PrometheusRule

The Operator generates Prometheus configuration automatically.

---

# 10. Why We Use kube-prometheus-stack

Instead of deploying components individually, we use kube-prometheus-stack because it provides:

Production defaults

Automatic upgrades

Prometheus Operator

CRDs

Grafana

Alertmanager

RBAC

ServiceMonitors

Node Exporter

kube-state-metrics

This significantly reduces operational complexity.

---

# 11. Every Pod Explained

Current deployment includes the following major pods.

## Prometheus Operator

Maintains Prometheus resources.

Watches ServiceMonitors.

Creates scrape configuration.

---

## Grafana

Displays dashboards.

Queries Prometheus and Loki.

---

## kube-state-metrics

Exports Kubernetes object metrics.

---

## Node Exporter

Exports Linux node metrics.

One pod runs on every worker node.

---

## Promtail

Collects logs.

One pod runs on every worker node.

---

## Alertmanager

Receives alerts.

Routes notifications.

---

## Prometheus

Stores metrics.

Executes PromQL.

Evaluates rules.

---

# 12. Why Your Pods Were Pending Earlier

Earlier in the project, several pods remained in the Pending state.

The scheduler reported:

```
Too many pods
```

This happened because the cluster initially contained only one worker node.

That node had reached its maximum pod capacity.

As a result:

- Grafana could not schedule.
- Auth Service replicas could not schedule.
- kube-state-metrics could not schedule.

After scaling the node group to two nodes, the Kubernetes scheduler distributed workloads across both nodes and all pending workloads became Running.

This demonstrates Kubernetes' scheduling behavior and the importance of planning node capacity.

---

# 13. Dashboard Strategy

Rather than creating dashboards manually, every dashboard will be stored as JSON in Git.

Advantages:

- Version control
- Peer review
- Disaster recovery
- Repeatability
- Consistency

Argo CD automatically synchronizes dashboard ConfigMaps to the cluster.

Grafana loads them during startup through provisioning.

---

# 14. Alert Strategy

Alerts will be divided into categories:

Cluster

Infrastructure

Application

Kubernetes

Business

Each category will have dedicated PrometheusRule resources.

Examples include:

Node Not Ready

High CPU

High Memory

Deployment Unavailable

Pod CrashLoopBackOff

Persistent Volume Almost Full

Application Error Rate

---

# 15. Scaling Strategy

The monitoring stack is designed to scale with the cluster.

Adding worker nodes automatically results in:

Additional Node Exporters

Additional Promtail instances

Additional metrics

Additional log collection

No manual changes are required.

---

# 16. Disaster Recovery

The observability platform is entirely declarative.

If the cluster is destroyed:

Terraform recreates infrastructure.

Argo CD reinstalls applications.

Grafana dashboards are restored.

Prometheus rules are restored.

Alertmanager configuration is restored.

ServiceMonitors are restored.

The platform returns to its previous operational state.

---

# 17. Enterprise Best Practices

This project follows enterprise observability principles:

- Monitoring as Code
- GitOps
- Immutable configuration
- Declarative dashboards
- Declarative alert rules
- Infrastructure reproducibility
- Automatic reconciliation
- Separation of concerns
- Version-controlled observability
- Kubernetes-native monitoring

---

# Summary

Observability is the operational intelligence layer of the platform.

Prometheus collects metrics, Loki stores logs, Grafana visualizes information, Alertmanager distributes alerts, and the Prometheus Operator automates configuration.

Together, these components provide engineers with complete visibility into the health, performance, and behavior of the Kubernetes platform while ensuring every aspect of the monitoring stack remains fully automated, reproducible, and managed through GitOps.