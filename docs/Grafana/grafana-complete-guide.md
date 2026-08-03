# Chapter 1 – Architecture and Monitoring Stack

# Enterprise Platform Observability

---

# Objective

The objective of this chapter is to explain the monitoring architecture of the Enterprise Platform before diving into Grafana.

By the end of this chapter, the reader should understand:

- How metrics flow through the platform
- How logs flow through the platform
- How dashboards receive their data
- How Kubernetes resources interact
- Why each monitoring component exists
- How GitOps manages the monitoring stack

This chapter provides the foundation for the remaining documentation.

---

# Monitoring Architecture

The Enterprise Platform uses a cloud-native observability stack built on Kubernetes.

The monitoring stack consists of:

- Spring Boot
- Micrometer
- Prometheus
- Grafana
- Loki
- Promtail
- ArgoCD

Each component has a specific responsibility.

```
                        +---------------------------+
                        |     Spring Boot App       |
                        |      (auth-service)       |
                        +------------+--------------+
                                     |
                                     |
                           /actuator/prometheus
                                     |
                                     |
                              Micrometer Metrics
                                     |
                                     |
                         +-----------v------------+
                         |     Kubernetes         |
                         |        Service         |
                         +-----------+------------+
                                     |
                                     |
                          ServiceMonitor discovers
                                     |
                                     |
                          +----------v-----------+
                          |     Prometheus       |
                          |   Metric Scraping    |
                          +----------+-----------+
                                     |
                +--------------------+--------------------+
                |                                         |
                |                                         |
        PromQL Queries                             Alert Rules
                |                                         |
                |                                         |
      +---------v----------+                   +----------v---------+
      |      Grafana       |                   |   Alertmanager     |
      | Dashboards & Graphs|                   | Notifications      |
      +---------+----------+                   +--------------------+
                |
                |
                |
       +--------v---------+
       |      Loki        |
       |  Application Logs|
       +--------+---------+
                |
                |
          +-----v------+
          | Promtail   |
          | Log Agent  |
          +------------+
```

---

# Monitoring Components

The Enterprise Platform monitoring solution is built from several open-source projects.

Each project has one responsibility.

Understanding these responsibilities is important before building dashboards.

---

# Spring Boot

The Enterprise Platform API is a Spring Boot application.

Spring Boot exposes application metrics through the Actuator endpoint.

```
/actuator/prometheus
```

This endpoint exposes hundreds of metrics including:

- CPU usage
- JVM heap usage
- HTTP request count
- HTTP response time
- Thread count
- Garbage collection
- Memory pools
- Process uptime

Spring Boot itself does not store metrics.

It only exposes them.

---

# Micrometer

Micrometer is the metrics instrumentation library used by Spring Boot.

Think of Micrometer as a translator.

Instead of Prometheus understanding Java directly,

Micrometer converts Java runtime information into Prometheus metrics.

Example:

```
http_server_requests_seconds_count

process_cpu_usage

jvm_memory_used_bytes

jvm_threads_live_threads
```

Without Micrometer,

Prometheus would have nothing to scrape.

---

# Kubernetes Service

The Spring Boot Pods are not scraped directly.

Instead,

Prometheus discovers a Kubernetes Service.

Example

```
auth-service
```

The Service forwards traffic to the Pods.

This is also how Prometheus reaches

```
/actuator/prometheus
```

---

# ServiceMonitor

This project uses the Prometheus Operator.

Instead of configuring scrape targets manually,

Prometheus watches Kubernetes ServiceMonitor resources.

Example

```
ServiceMonitor

↓

Selector

↓

Service Labels

↓

Target Endpoint
```

This allows Prometheus to automatically discover applications.

One important lesson learned during this project:

> Prometheus only discovers Services whose labels match the ServiceMonitor selector.

This became one of the primary troubleshooting issues during implementation and is discussed in Chapter 8.

---

# Prometheus

Prometheus is the metrics database.

Responsibilities include:

- Discovering applications
- Scraping metrics
- Storing metrics
- Executing PromQL queries
- Supplying data to Grafana

Prometheus does **not** draw graphs.

It only stores metrics.

---

# PromQL

PromQL is Prometheus Query Language.

Grafana uses PromQL to retrieve metrics.

Example

```promql
up
```

Returns every target currently being scraped.

Example

```promql
avg(process_cpu_usage{job="auth-service"})
```

Returns average CPU utilization.

Throughout this guide, every dashboard panel will use PromQL.

---

# Grafana

Grafana is responsible for visualization.

Grafana never collects metrics itself.

Instead,

Grafana sends PromQL queries to Prometheus.

Prometheus returns time-series data.

Grafana renders:

- Graphs
- Gauges
- Tables
- Statistics
- Heatmaps
- Logs

---

# Loki

Prometheus stores metrics.

Loki stores logs.

Application logs are not queried using PromQL.

Instead,

Grafana uses LogQL when communicating with Loki.

This separation allows metrics and logs to be correlated without storing duplicate information.

---

# Promtail

Promtail is the log shipping agent.

Responsibilities:

- Read Kubernetes container logs
- Add Kubernetes labels
- Push logs into Loki

Promtail runs as a DaemonSet.

One Pod runs on every Kubernetes node.

---

# Grafana Data Sources

The Enterprise Platform uses multiple Grafana data sources.

| Data Source | Purpose |
|-------------|---------|
| Prometheus | Metrics |
| Loki | Logs |
| Alertmanager | Alert visualization |

Each dashboard panel selects one datasource.

Most custom dashboards built during this project use Prometheus.

The Live Logs panel uses Loki.

---

# GitOps Architecture

The entire monitoring platform is managed using GitOps.

```
Developer

↓

Git Commit

↓

GitHub Repository

↓

ArgoCD

↓

Kubernetes Cluster

↓

Grafana
```

Every dashboard,

ConfigMap,

and monitoring configuration

is stored in Git.

Manual changes inside Grafana should eventually be exported back into Git to keep Git as the single source of truth.

---

# Repository Structure

The monitoring resources are organized as follows.

```
enterprise-platform-gitops/

charts/

├── monitoring/

│   ├── Chart.yaml

│   ├── values.yaml

│   ├── templates/

│   └── values/

├── monitoring-assets/

│   ├── dashboards/

│   │   ├── application/

│   │   ├── enterprise-platform-overview/

│   │   └── infrastructure/

│   ├── templates/

│   │   ├── dashboards-configmap.yaml

│   │   └── dashboard-provider.yaml

│   ├── Chart.yaml

│   └── values.yaml

applications/

├── prometheus-stack.yaml

├── loki.yaml

├── promtail.yaml

└── monitoring-assets.yaml
```

This separation allows the monitoring stack and dashboard assets to evolve independently while remaining fully managed through ArgoCD.

---

# Monitoring Workflow

The complete metrics workflow is:

```
Spring Boot

↓

Micrometer

↓

/actuator/prometheus

↓

Kubernetes Service

↓

ServiceMonitor

↓

Prometheus

↓

PromQL

↓

Grafana Dashboard
```

The complete logging workflow is:

```
Application

↓

Container Logs

↓

Promtail

↓

Loki

↓

Grafana Logs Panel
```

---

# Summary

By the end of this chapter, the reader should understand:

- The role of each monitoring component.
- How metrics move from the application into Grafana.
- The difference between metrics and logs.
- Why Prometheus, Grafana, Loki, and Promtail are separate services.
- How GitOps is used to manage the monitoring platform.

The next chapter explains how Grafana was installed, exposed through an AWS Application Load Balancer, and configured for secure access.

# Chapter 2 – Installing and Accessing Grafana

# Installing and Accessing Grafana

---

# Objective

The objective of this chapter is to explain how Grafana was deployed, configured, and exposed within the Enterprise Platform Kubernetes cluster.

After completing this chapter, a reader should be able to:

- Understand why Grafana is required.
- Deploy Grafana using the kube-prometheus-stack Helm chart.
- Expose Grafana through an AWS Application Load Balancer (ALB).
- Configure HTTPS using AWS Certificate Manager (ACM).
- Configure DNS using ExternalDNS.
- Verify that Grafana is operational.
- Log in to Grafana.
- Understand how Grafana discovers Prometheus and Loki.

This chapter assumes that:

- Kubernetes is already running.
- ArgoCD has been installed.
- The AWS Load Balancer Controller is operational.
- ExternalDNS is operational.
- Cert Manager is installed.
- Prometheus Stack has already been deployed.

---

# Why Grafana?

Prometheus stores metrics.

However, Prometheus has very limited visualization capabilities.

Grafana provides:

- Rich dashboards
- Interactive graphs
- Alert visualization
- Multiple datasources
- Role-based access
- Dashboard sharing
- GitOps integration

Grafana is therefore the primary visualization platform for the Enterprise Platform.

---

# Deployment Method

Grafana is **not** installed separately.

Instead, it is deployed as part of the **kube-prometheus-stack** Helm chart.

The monitoring stack deployed in this project consists of:

- Prometheus Operator
- Prometheus
- Grafana
- Alertmanager
- kube-state-metrics
- Node Exporter

Deploying these components together ensures compatibility and simplifies upgrades.

---

# GitOps Deployment

Grafana is deployed through ArgoCD.

Application:

```

prometheus-stack

```

Repository

```

enterprise-platform-gitops

```

Helm Chart

```

prometheus-community/kube-prometheus-stack

```

Destination Namespace

```

monitoring

```

Because ArgoCD manages this deployment, no manual Helm installation should be performed directly against the cluster.

All configuration changes should be committed to Git.

---

# Deployment Flow

```
Developer

↓

Git Push

↓

GitHub Repository

↓

ArgoCD

↓

Prometheus Stack

↓

Grafana Deployment

↓

Grafana Service

↓

Ingress

↓

AWS ALB

↓

Internet
```

---

# Kubernetes Resources Created

Deploying kube-prometheus-stack creates several resources.

Example:

Deployment

```
prometheus-stack-grafana
```

Service

```
prometheus-stack-grafana
```

ConfigMaps

```
prometheus-stack-grafana

prometheus-stack-kube-prom-grafana-datasource
```

PersistentVolumeClaim

```
prometheus-stack-grafana
```

Ingress

```
prometheus-stack-grafana
```

Verify:

```bash
kubectl get all -n monitoring
```

---

# Verifying the Grafana Deployment

Confirm that the Deployment exists.

```bash
kubectl get deployment -n monitoring
```

Expected output

```
prometheus-stack-grafana
```

---

Verify Pods.

```bash
kubectl get pods -n monitoring
```

Expected

```
Running

3/3 Ready
```

If Pods are not Running, inspect them.

```bash
kubectl describe pod <pod-name> -n monitoring
```

Check logs.

```bash
kubectl logs <pod-name> -n monitoring
```

---

# Verifying the Service

Confirm that Grafana is exposed internally.

```bash
kubectl get svc -n monitoring
```

Expected Service

```
prometheus-stack-grafana
```

Example

```
TYPE

ClusterIP
```

The Service forwards requests to the Grafana Pods.

---

# Persistent Storage

Grafana stores dashboards, users, and configuration.

Persistent storage is provided through a PersistentVolumeClaim.

Verify:

```bash
kubectl get pvc -n monitoring
```

Expected

```
prometheus-stack-grafana
```

Status

```
Bound
```

Without persistent storage:

- Dashboards are lost after Pod recreation.
- Users are recreated.
- Settings are reset.

---

# Exposing Grafana

Grafana is exposed through an AWS Application Load Balancer.

Ingress

```
prometheus-stack-grafana
```

Verify

```bash
kubectl get ingress -n monitoring
```

Example

```
NAME

prometheus-stack-grafana

CLASS

alb

HOST

grafana.dev.dreammyles.online
```

---

# Ingress Configuration

The Ingress uses the following annotations.

```
alb.ingress.kubernetes.io/scheme:
internet-facing

alb.ingress.kubernetes.io/target-type:
ip

alb.ingress.kubernetes.io/group.name:
enterprise-platform

alb.ingress.kubernetes.io/listen-ports:
HTTP + HTTPS

alb.ingress.kubernetes.io/ssl-redirect:
443
```

These annotations instruct the AWS Load Balancer Controller to provision an internet-facing Application Load Balancer with HTTP-to-HTTPS redirection.

---

# HTTPS

HTTPS is provided using an AWS Certificate Manager (ACM) certificate.

The Ingress references the ACM certificate through:

```
alb.ingress.kubernetes.io/certificate-arn
```

This allows TLS termination at the ALB.

Application traffic between the ALB and Grafana continues over the Kubernetes Service.

---

# DNS

ExternalDNS automatically creates Route 53 DNS records.

Hostname

```
grafana.dev.dreammyles.online
```

Points to

```
AWS Application Load Balancer
```

Verify:

```bash
kubectl get ingress -n monitoring
```

The ADDRESS column should contain the ALB hostname.

---

# Accessing Grafana

Open a browser.

Navigate to:

```
https://grafana.dev.dreammyles.online
```

The Grafana login page should appear.

If the page does not load:

- Verify the Ingress.
- Verify the ALB.
- Verify Route 53 records.
- Verify the AWS Load Balancer Controller.
- Verify that the Grafana Pods are Running.

---

# Retrieving Login Credentials

The administrator credentials are stored in a Kubernetes Secret.

Verify available secrets.

```bash
kubectl get secrets -n monitoring
```

Retrieve the username.

```bash
kubectl get secret grafana-secret \
-n monitoring \
-o jsonpath="{.data.username}" | base64 -d
```

Retrieve the password.

```bash
kubectl get secret grafana-secret \
-n monitoring \
-o jsonpath="{.data.password}" | base64 -d
```

> **Note:** If you configured a different secret name in your Helm values, replace `grafana-secret` with the appropriate Secret name.

---

# First Login

After logging in:

Grafana displays:

- Home
- Dashboards
- Drilldown
- Alerting
- Connections
- Administration

At this point no custom dashboards have been imported.

Only the default Grafana home page is displayed.

---

# Datasources

Grafana automatically discovers datasources configured by the Prometheus Stack.

Navigate to:

```
Connections

↓

Data Sources
```

Expected datasources

```
Prometheus

Loki

Alertmanager
```

Prometheus provides metrics.

Loki provides logs.

Alertmanager displays active alerts.

These datasources were automatically configured through the Prometheus Stack deployment.

---

# Verifying Prometheus Connectivity

Select the Prometheus datasource.

Click

```
Save & Test
```

Expected message

```
Datasource is working.
```

If the test fails:

- Verify the Prometheus Pods.
- Verify the Prometheus Service.
- Verify network connectivity.
- Verify the datasource URL.

---

# Verifying Loki

Open

```
Connections

↓

Data Sources

↓

Loki
```

Click

```
Save & Test
```

Expected

```
Datasource is working.
```

---

# Lessons Learned During This Project

Several issues were encountered while exposing Grafana.

## Issue 1 – AWS Load Balancer Controller Was Missing

**Symptoms**

- Ingress remained without an ADDRESS.
- No ALB was provisioned.
- `kubectl get ingress` showed an empty `ADDRESS` field.

**Root Cause**

The `aws-load-balancer-controller` ArgoCD application had been changed to point to the `manifests/storage` directory instead of the Helm chart deployment. As a result, ArgoCD pruned the Deployment, Service, and related resources, leaving only the `gp3` StorageClass.

**Resolution**

The Application manifest was restored to the Helm chart configuration:

- Chart: `aws-load-balancer-controller`
- Namespace: `kube-system`
- Values file: `charts/aws-load-balancer-controller/values.yaml`

After syncing:

```bash
kubectl get deployment -n kube-system
kubectl get ingressclass
```

confirmed that the controller and the `alb` IngressClass were recreated.

---

## Issue 2 – Grafana Ingress Waiting

**Symptoms**

The `prometheus-stack` application remained in the **Progressing** state.

ArgoCD displayed:

```
Waiting for healthy state of networking.k8s.io/Ingress/prometheus-stack-grafana
```

**Root Cause**

Without the AWS Load Balancer Controller, the Ingress could not be reconciled and no ALB was created.

**Resolution**

Once the controller was restored, the Ingress reconciled successfully, the ALB hostname appeared, and the application became Healthy.

---

## Verification Checklist

Before proceeding to dashboard creation, verify:

- ✅ Grafana Deployment is Running.
- ✅ Grafana Service exists.
- ✅ PersistentVolumeClaim is Bound.
- ✅ Ingress has an ALB hostname.
- ✅ DNS resolves correctly.
- ✅ HTTPS is working.
- ✅ Login succeeds.
- ✅ Prometheus datasource is healthy.
- ✅ Loki datasource is healthy.
- ✅ Alertmanager datasource is healthy.

---

# Summary

At the end of this chapter, Grafana should be fully operational and accessible through `https://grafana.dev.dreammyles.online`.

The next chapter explores the Grafana user interface, explains the purpose of each navigation item, and demonstrates how to create dashboards and panels using both Builder Mode and Code Mode with PromQL.

# Chapter 3 – Understanding the Grafana User Interface

---

# Objective

After completing this chapter, you will be able to:

- Navigate the Grafana interface
- Understand each menu option
- Understand the difference between Dashboards, Explore, Drilldown and Alerting
- Understand Prometheus datasources
- Understand Builder Mode vs Code Mode
- Create your first panel
- Execute your first PromQL query
- Configure panel options
- Save dashboards

This chapter assumes Grafana has already been deployed successfully.

---

# Logging Into Grafana

Open

https://grafana.dev.dreammyles.online

Login using the administrator credentials retrieved from Kubernetes.

After authentication, Grafana opens the Home page.

---

# Grafana Navigation Menu

The left navigation menu contains several sections.

```

Home

Dashboards

Drilldown

Alerting

Connections

Administration

```

Each section serves a different purpose.

---

# Home

Home displays:

- Recently viewed dashboards
- Starred dashboards
- Recently edited dashboards

This page is primarily informational.

---

# Dashboards

This is the section used most frequently during this project.

Navigation:

```

Dashboards

↓

New

↓

New Dashboard

```

Dashboards are collections of visual panels.

Each panel displays one or more Prometheus or Loki queries.

---

# Drilldown

Grafana 12 renamed **Explore** to **Drilldown**.

During implementation, the interface displayed the message:

```
Explore Metrics, Logs, Traces and Profiles have moved!

Looking for the Grafana Explore apps?

They are now called the Grafana Drilldown apps.
```

This confused the initial setup because older tutorials still refer to **Explore**.

For Grafana 12:

```

Explore

↓

Drilldown

```

are equivalent.

---

# Alerting

The Alerting section manages Grafana-managed alerts.

Although Alertmanager was installed,

alert creation was not part of the initial monitoring implementation.

Alerting will be implemented in a future phase.

---

# Connections

Connections manages external integrations.

Most importantly,

it contains the configured datasources.

Navigate to

```

Connections

↓

Data Sources

```

Expected datasources:

```

Prometheus

Loki

Alertmanager

```

---

# Administration

Administration contains:

- Users
- Authentication
- Plugins
- Settings
- Organizations

Most day-to-day dashboard work does not require this section.

---

# Creating the First Dashboard

Navigate to

```

Dashboards

↓

New

↓

New Dashboard

```

Grafana displays

```

Add Visualization

```

Click

```

Add Visualization

```

Grafana now asks for a datasource.

---

# Selecting a Datasource

Choose

```

Prometheus

```

Do **not** choose:

- Loki
- Alertmanager

Those datasources are used for different purposes.

Prometheus provides application and infrastructure metrics.

---

# The Panel Editor

After selecting Prometheus,

Grafana opens the Panel Editor.

The screen contains four primary sections.

```

Panel Preview

Datasource

Query Editor

Right Sidebar

```

Understanding these sections is critical.

---

# Panel Preview

Located at the top.

Initially,

the preview is empty.

As queries are executed,

the preview updates automatically.

This allows immediate feedback while building panels.

---

# Datasource Selector

Located directly above the Query Editor.

Example

```

A (Prometheus)

```

This indicates that Query A uses the Prometheus datasource.

A panel may contain multiple datasources,

although this project uses a single datasource per panel.

---

# Query Editor

Initially,

Grafana displays

```

Kick start your query

Metric

Select Metric

Label Filters

Operations

```

This is called **Builder Mode**.

---

# Builder Mode

Builder Mode generates PromQL automatically.

Advantages

- Easy for beginners
- Discover metrics
- Browse labels
- Learn PromQL

Disadvantages

- Harder to reproduce
- Less flexible
- Difficult to document
- Generates verbose queries

Builder Mode was used briefly while exploring metrics.

Production dashboards use Code Mode.

---

# Switching to Code Mode

Locate

```

Builder

```

↓

Click

```

Code

```

Grafana replaces the visual editor with a raw text editor.

This is where PromQL is entered.

Example

```promql
up
```

---

# Running a Query

After entering a query,

click

```

Run Queries

```

Grafana immediately executes the PromQL query.

Possible outcomes:

Success

```

Graph displayed

```

No Data

```

No Data

```

Error

```

Parse Error

```

---

# Understanding "No Data"

"No Data" does **not** necessarily indicate a problem with Grafana.

It usually means one of the following:

- Prometheus is not scraping the target
- Incorrect metric name
- Incorrect labels
- Application has received no traffic
- Wrong datasource selected

This became an important troubleshooting scenario during implementation.

---

# Panel Options

The right-hand sidebar controls panel appearance.

Important sections include:

```

Visualization

Panel Options

Standard Options

Thresholds

Value Mappings

Overrides

Transformations

```

Each section changes how the data is presented.

---

# Visualization Types

Grafana supports many visualization types.

The Enterprise Platform primarily uses four.

## Stat

Displays a single numeric value.

Used for:

- Requests/sec
- Error Rate
- Running Pods
- API Health

---

## Gauge

Displays utilization against thresholds.

Used for:

- CPU Usage
- Container Memory %
- JVM Heap %

---

## Time Series

Displays historical trends.

Used for:

- Request Rate
- CPU Usage Over Time
- Heap Usage
- Response Time

---

## Logs

Displays Loki log streams.

Used for:

- Live Application Logs

---

# Panel Titles

Each panel should have a meaningful title.

Examples

```

Requests / sec

Average Response Time

CPU Usage %

Running Pods

Error Rate

Container Memory %

JVM Heap %

Live Threads

```

Avoid generic names such as

```

Graph

Panel 1

Metric

```

---

# Saving a Dashboard

After adding one or more panels,

click

```

Save Dashboard

```

Grafana prompts for:

Title

Description

Folder

Recommended values

Title

```

Enterprise Platform Overview

```

Description

```

Production monitoring dashboard for the Enterprise Platform.

Displays application, infrastructure, JVM and Kubernetes metrics.

```

Folder

```

Dashboards

```

Click

```

Save

```

The dashboard is now available from the Dashboards menu.

---

# Lessons Learned During This Project

Several UI changes in Grafana 12 caused confusion during implementation.

### Explore became Drilldown

Older tutorials referenced:

```

Explore

```

Grafana 12 displays:

```

Drilldown

```

These are equivalent.

---

### Builder Mode vs Code Mode

Initially,

queries were entered through Builder Mode.

Later,

Code Mode was adopted because:

- PromQL is easier to document
- Queries can be version controlled
- Easier to troubleshoot
- Matches production practices

All custom dashboards documented in this guide use Code Mode.

---

### Prometheus Datasource

During dashboard creation,

multiple datasources appeared:

- Prometheus
- Loki
- Alertmanager

Prometheus was selected for all metric panels.

Loki will be used only for the Live Logs panel.

---

# Verification Checklist

Before proceeding,

confirm the following:

- Grafana is accessible.
- Login succeeds.
- Prometheus datasource is healthy.
- Dashboard creation succeeds.
- Code Mode is available.
- PromQL queries execute successfully.
- Dashboards can be saved.

---

# Summary

You now understand the Grafana user interface and the workflow used throughout this project.

The next chapter documents, in detail, how each dashboard panel was created—including every click, every PromQL query, every visualization option, and every configuration setting.

# Chapter 4 – Building Dashboards (Every Click)

---

# Objective

This chapter documents the complete process used to create the Enterprise Platform Overview dashboard.

Unlike the community dashboards imported later in this guide, every panel described in this chapter was built manually using Prometheus metrics.

The purpose of documenting every step is to ensure that another engineer can recreate the dashboard without relying on screenshots, external tutorials, or prior Grafana experience.

By the end of this chapter, you will have built the same operational dashboard used throughout this project.

---

# Prerequisites

Before continuing, verify the following:

- Grafana is accessible.
- Prometheus is healthy.
- Prometheus is configured as a Grafana datasource.
- The `auth-service` application is running.
- Prometheus is successfully scraping `auth-service`.
- Spring Boot Actuator is enabled.
- The `/actuator/prometheus` endpoint is reachable.
- The `ServiceMonitor` is discovering the application.

If any of these prerequisites are not met, refer to Chapter 8 (Troubleshooting).

---

# Dashboard Design Philosophy

The Enterprise Platform Overview dashboard was intentionally designed to answer a single question:

> **Is the platform healthy?**

Rather than creating multiple dashboards, the goal was to provide a single operational view that allows an engineer to assess the overall health of the system within a few seconds.

The dashboard combines:

- Application metrics
- JVM metrics
- Kubernetes metrics
- Infrastructure metrics
- Request metrics
- Live logs

into one dashboard.

This mirrors dashboards commonly used by Site Reliability Engineering (SRE) teams.

---

# Final Dashboard Layout

The completed dashboard is organized as follows.

```

Enterprise Platform Overview

┌──────────────────────────────────────────────────────────────────────┐
│ API Health │ Requests/s │ Avg Response │ Error Rate │ Running Pods │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ CPU Usage %                    │ Container Memory %                │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ JVM Heap %                    │ Live Threads                       │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ Request Rate (Time Series)                                       │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ CPU Usage Over Time                                              │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ JVM Heap Usage Over Time                                         │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ Live Application Logs (Loki)                                     │
└──────────────────────────────────────────────────────────────────────┘

```

Each panel was intentionally selected to represent one aspect of application health.

---

# Creating the Dashboard

Open Grafana.

Navigate to:

```

Dashboards

↓

New

↓

New Dashboard

```

Grafana displays a page containing a single button.

```

Add visualization

```

Click **Add visualization**.

---

# Selecting the Datasource

Grafana prompts for a datasource.

Three datasources are available.

```
Prometheus

Loki

Alertmanager
```

Select:

```
Prometheus
```

All metric panels in this dashboard use the Prometheus datasource.

The Loki datasource will only be used for the Live Logs panel.

---

# Understanding the Panel Editor

After selecting Prometheus, Grafana opens the Panel Editor.

During implementation, the interface displayed:

```

Kick start your query

Metric

Label Filters

Operations

```

This is Grafana's **Builder Mode**.

Initially, Builder Mode was used while exploring available metrics.

However, for all production panels, Code Mode was selected because it provides full control over PromQL queries and is easier to document.

---

# Switching to Code Mode

Locate the toggle labeled:

```

Builder

```

Click:

```

Code

```

The visual query builder is replaced by a raw PromQL editor.

All remaining sections of this guide assume Code Mode is being used.

---

# Running a Query

After entering a PromQL query, click:

```

Run Queries

```

Grafana immediately executes the query against Prometheus.

If the query is successful, the panel preview updates automatically.

If the panel displays **No Data**, refer to Chapter 8 before continuing.
