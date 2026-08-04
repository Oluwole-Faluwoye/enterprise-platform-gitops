Grafana Dashboard GitOps Provisioning
Overview

This document describes how Grafana dashboards are provisioned automatically using Helm, ArgoCD, and GitOps.

Instead of creating dashboards manually in the Grafana UI, dashboards are stored as JSON files in Git. ArgoCD continuously monitors the repository and automatically updates Grafana whenever dashboard changes are committed.

Architecture
Dashboard JSON
      │
      ▼
Git Repository
      │
      ▼
ArgoCD
      │
      ▼
Helm Chart
      │
      ▼
ConfigMaps
      │
      ▼
Grafana Dashboard Sidecar
      │
      ▼
Grafana UI
Repository Structure
charts/
└── monitoring-assets/
    ├── dashboards/
    │   ├── Applications/
    │   ├── Infrastructure/
    │   └── Enterprise-Platform-Overview/
    │
    ├── grafana/
    │   ├── datasources/
    │   ├── providers/
    │   └── folders/
    │
    └── templates/
        ├── grafana-dashboards.yaml
        ├── grafana-dashboard-provider.yaml
        └── grafana-datasources.yaml

Dashboards remain organized by category while Helm recursively discovers every dashboard.

Dashboard Provisioning

Dashboards are provisioned from:

charts/monitoring-assets/dashboards/

Example:

dashboards/
├── Applications/
│   ├── jvm-micrometer.json
│   └── springboot-statistics.json
│
├── Infrastructure/
│   ├── node-exporter.json
│   ├── kubernetes-nodes.json
│   └── kubernetes-cluster-views.json
│
└── Enterprise-Platform-Overview/
    └── enterprise-platform-overview.json
Helm Dashboard Discovery

The chart discovers dashboards recursively:

{{- $files := .Files.Glob "dashboards/**/*.json" }}

This allows dashboards to remain organized in folders without changing the Helm template whenever a new dashboard is added.

Dashboard ConfigMaps

Each dashboard is rendered into its own ConfigMap.

Example:

grafana-dashboard-enterprise-platform-overview
grafana-dashboard-jvm-micrometer
grafana-dashboard-node-exporter
grafana-dashboard-kubernetes-nodes

Each ConfigMap contains exactly one dashboard JSON.

Example:

metadata:
  name: grafana-dashboard-jvm-micrometer

labels:
  grafana_dashboard: "1"
Why One ConfigMap Per Dashboard?

Originally, every dashboard was stored inside a single ConfigMap.

Example:

enterprise-platform-dashboards

This eventually exceeded Kubernetes annotation limits and ArgoCD failed with:

metadata.annotations: Too long

Splitting dashboards into individual ConfigMaps provides:

easier maintenance
smaller Kubernetes objects
better scalability
easier troubleshooting
production-friendly architecture
Dashboard Folder Mapping

Dashboard folders are automatically determined from the directory structure.

Template:

annotations:
  grafana_folder: {{ dir $path | base }}

Example:

dashboards/
├── Applications/
├── Infrastructure/
└── Enterprise-Platform-Overview/

becomes Grafana folders:

Applications
Infrastructure
Enterprise-Platform-Overview

without additional configuration.

Grafana Datasources

Datasource definitions are stored under:

grafana/datasources/

Example:

prometheus.yaml
loki.yaml
datasources.yaml

Each datasource is provisioned as an individual ConfigMap.

To avoid conflicts with other ArgoCD applications, datasource ConfigMaps are prefixed:

grafana-datasource-prometheus
grafana-datasource-loki
grafana-datasource-datasources

instead of

prometheus
loki

This prevents resource ownership conflicts.

ArgoCD Configuration

Automatic synchronization is enabled.

syncPolicy:
  automated:
    prune: true
    selfHeal: true

  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    - Replace=true
ServerSideApply

Server-side apply avoids Kubernetes annotation size limitations for large dashboard ConfigMaps.

Replace

Replace ensures large ConfigMaps can be updated reliably during synchronization.

Dashboard Update Workflow
Modify dashboard in Grafana.
Export dashboard JSON.
Save the JSON into:
dashboards/<Folder>/<dashboard>.json
Commit changes.
git add .
git commit -m "Update dashboard"
git push
ArgoCD automatically detects the Git commit.
Helm renders the updated ConfigMap.
Kubernetes updates the ConfigMap.
Grafana reloads the dashboard automatically.

No manual dashboard import is required.

Validation

Confirm ArgoCD synchronization:

kubectl get application monitoring-assets -n argocd

Expected:

SYNC STATUS: Synced
HEALTH: Healthy

List dashboard ConfigMaps:

kubectl get configmaps -n monitoring | grep grafana-dashboard

Expected:

grafana-dashboard-enterprise-platform-overview
grafana-dashboard-jvm-micrometer
grafana-dashboard-node-exporter
grafana-dashboard-kubernetes-cluster-views
...

Verify GitOps:

Change a dashboard JSON.
Commit and push.
Wait for ArgoCD to synchronize.
Refresh Grafana.
Confirm the dashboard reflects the new change.
Lessons Learned
Issue 1 – Recursive Dashboard Discovery
Problem

Helm only searched:

dashboards/*.json

Nested folders were ignored.

Solution

Changed to:

dashboards/**/*.json

allowing recursive discovery.

Issue 2 – Oversized ConfigMap
Problem

All dashboards were stored in one ConfigMap, causing Kubernetes annotation limits to be exceeded.

Solution

Generate one ConfigMap per dashboard.

Issue 3 – Large Dashboard Synchronization
Problem

Large community dashboards (for example, Node Exporter) exceeded ArgoCD client-side apply limits.

Solution

Enable:

ServerSideApply=true
Replace=true
Issue 4 – Loki ConfigMap Conflict
Problem

Both the monitoring-assets and loki ArgoCD applications created a ConfigMap named:

loki

causing a SharedResourceWarning.

Solution

Rename Grafana datasource ConfigMaps with a prefix:

grafana-datasource-loki

to avoid resource ownership conflicts.

Result

The monitoring stack now follows a fully GitOps-based workflow:

Dashboards stored in Git
Helm provisions dashboards automatically
ArgoCD continuously synchronizes changes
Grafana reloads dashboards automatically
No manual dashboard management in production
One ConfigMap per dashboard
Automatic folder organization
Production-ready synchronization using Server-Side Apply and Replace

This implementation provides a scalable, maintainable, and production-friendly approach to managing Grafana dashboards in Kubernetes.