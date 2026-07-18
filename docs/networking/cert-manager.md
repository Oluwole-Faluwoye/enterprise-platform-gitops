                     Internet
                         │
                         ▼
                  Route53 Hosted Zone
                         │
                         ▼
                  ExternalDNS
                         │
                         ▼
          AWS Load Balancer Controller
                         │
                         ▼
                 AWS Application Load Balancer
                         │
                ACM Certificate (HTTPS)
                         │
                         ▼
                     One Ingress
         ┌───────────────┼────────────────┐
         ▼               ▼                ▼
  api.platform...  grafana.platform...  argocd.platform...
         │               │                │
         ▼               ▼                ▼
   Auth Service      Grafana         Argo CD