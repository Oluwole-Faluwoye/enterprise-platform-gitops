Grafana Datasources, Alertmanager & GitOps Provisioning
Overview

The Enterprise Platform uses GitOps with ArgoCD to manage all monitoring components.

The monitoring stack consists of:

Prometheus
Grafana
Alertmanager
Loki

The objective is to ensure every monitoring configuration is:

version controlled
reproducible
automatically deployed by ArgoCD
never manually configured through the Grafana UI
Initial Problem

Initially, Grafana was provisioning datasources from two different sources.

Source 1

kube-prometheus-stack

Generated:

prometheus-stack-kube-prom-grafana-datasource

which contained

datasource.yaml
Source 2

Monitoring Assets Chart

Generated

grafana-datasource-prometheus
grafana-datasource-loki
grafana-datasource-alertmanager

Each ConfigMap provisioned a datasource independently.

Result

Grafana continuously reported:

Datasource provisioning error:

Only one datasource per organization can be marked as default

because multiple provisioning files attempted to manage the same datasource.

Root Cause

The monitoring architecture had two competing owners for datasource provisioning.

kube-prometheus-stack
            │
            ▼
datasource.yaml
            ▲
            │
monitoring-assets

Grafana sidecar merged every ConfigMap labeled

grafana_datasource=1

which caused conflicts.

Investigation

We verified the issue by inspecting the Grafana container.

kubectl exec -it \
deploy/prometheus-stack-grafana \
-n monitoring \
-c grafana -- sh

Listing datasource files:

ls -l /etc/grafana/provisioning/datasources

Initially showed

alertmanager.yaml
prometheus.yaml
loki.yaml
datasource.yaml

meaning four provisioning files were being loaded.

We also inspected the generated ConfigMaps.

kubectl get configmap \
-n monitoring

revealed

grafana-datasource-alertmanager
grafana-datasource-loki
grafana-datasource-prometheus
prometheus-stack-kube-prom-grafana-datasource
Solution

Instead of provisioning one ConfigMap per datasource, all datasources were consolidated into a single ConfigMap.

grafana-datasource-datasources

This ConfigMap provisions

Prometheus
Loki
Alertmanager

from a single YAML file.

Directory structure

charts/
└── monitoring-assets
    ├── templates
    │      grafana-datasources.yaml
    │
    └── grafana
           └── datasources
                 datasources.yaml

datasources.yaml

contains

Prometheus

Loki

Alertmanager

as a single provisioning file.

Template

grafana-datasources.yaml

creates

enterprise-datasources.yaml

inside Grafana.

kube-prometheus-stack Configuration

Datasource provisioning from the Helm chart was disabled.

grafana:

  sidecar:

    datasources:

      enabled: true

      defaultDatasourceEnabled: false

This prevents kube-prometheus-stack from generating its default Prometheus datasource.

The sidecar remains enabled because it is responsible for discovering ConfigMaps labeled

grafana_datasource=1
Dashboard Providers

Dashboard provisioning is handled separately.

Custom provider

Enterprise Platform

was removed.

Instead, the Grafana Sidecar Provider is used.

Resulting provider:

sidecarProvider

All dashboards are loaded automatically from

/var/lib/grafana/dashboards
Final Datasource Layout

Inside the Grafana container

/etc/grafana/provisioning/datasources

contains

datasource.yaml
enterprise-datasources.yaml

where

datasource.yaml

is an empty placeholder created by kube-prometheus-stack

apiVersion: 1

datasources:

and

enterprise-datasources.yaml

contains

Prometheus
Loki
Alertmanager

Since the placeholder contains no datasources, no conflict occurs.

Alertmanager

Alertmanager is provisioned as a datasource instead of being manually added through the Grafana UI.

Datasource settings

Type

Alertmanager

Implementation

Prometheus

URL

http://prometheus-stack-kube-prom-alertmanager.monitoring.svc.cluster.local:9093

Health Check

Health check passed.
Loki

Loki is also provisioned through GitOps.

Datasource

Type

Loki

URL

http://loki.monitoring.svc.cluster.local:3100

Logs can be queried from

Explore

↓

Loki
Prometheus

Prometheus remains the default datasource.

UID

prometheus

URL

http://prometheus-stack-kube-prom-prometheus.monitoring.svc.cluster.local:9090
Verification

Datasource files

kubectl exec \
deploy/prometheus-stack-grafana \
-c grafana \
-- \
sh -c 'cat /etc/grafana/provisioning/datasources/*.yaml'

Dashboard providers

kubectl exec \
deploy/prometheus-stack-grafana \
-c grafana \
-- \
sh -c 'find /etc/grafana/provisioning/dashboards -type f -exec cat {} \;'

Datasource reload logs

kubectl logs \
deploy/prometheus-stack-grafana \
-c grafana-sc-datasources

Expected

Datasources config reloaded
Lessons Learned
Only one component should own datasource provisioning.
Grafana Sidecar should discover ConfigMaps, not individual manually managed datasource files.
Keep all datasource definitions in a single provisioning file.
Store datasource configuration in Git rather than creating them through the Grafana UI.
Verify the rendered provisioning files inside the Grafana container when troubleshooting.
Alertmanager, Loki, and Prometheus should all be provisioned declaratively via GitOps to ensure reproducibility.
Final Architecture
                         GitHub
                            │
                            ▼
                       ArgoCD Sync
                            │
        ┌───────────────────┴───────────────────┐
        ▼                                       ▼
kube-prometheus-stack                 monitoring-assets
        │                                       │
        │                                       │
        ▼                                       ▼
 Empty datasource.yaml             enterprise-datasources.yaml
        │                                       │
        └───────────────┬───────────────────────┘
                        ▼
              Grafana Sidecar (grafana_datasource=1)
                        │
                        ▼
      /etc/grafana/provisioning/datasources
                        │
                        ▼
                   Grafana
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
   Prometheus         Loki        Alertmanager
Why this approach?

This approach gives you:

GitOps-first configuration — every monitoring change is version-controlled.
Single source of truth — all datasource definitions live in one provisioning file.
Repeatable deployments — rebuilding the cluster recreates the exact Grafana configuration.
No manual UI configuration — Grafana remains fully declarative, making it ideal for automated environments and production-ready platform engineering.