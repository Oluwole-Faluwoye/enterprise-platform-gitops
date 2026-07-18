                           Internet
                               │
                               ▼
                     Route53 Hosted Zone
                               │
                               ▼
                    AWS Application Load Balancer
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
  grafana.platform.com   argocd.platform.com   api.platform.com
          │                    │                    │
          ▼                    ▼                    ▼
       Grafana              ArgoCD           Auth Service