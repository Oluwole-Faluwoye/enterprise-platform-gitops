Monitoring Assets Helm Chart

Purpose

This chart provisions all observability configuration used by the Enterprise Platform.

Responsibilities

• Grafana dashboards
• Grafana datasources
• Dashboard providers
• Alertmanager configuration
• Prometheus alert rules
• Recording rules
• ServiceMonitors
• Ingress resources

The monitoring stack itself is deployed by the monitoring Helm chart.

This chart only contains configuration assets.

All resources are deployed through ArgoCD.