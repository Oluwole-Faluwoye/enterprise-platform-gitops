Spring Boot App
       │
       ├──────── Metrics
       │             ↓
       │        Prometheus
       │             ↓
       │         Grafana
       │
       ├──────── Logs
       │             ↓
       │         Promtail
       │             ↓
       │           Loki
       │             ↓
       │         Grafana
       │
       └──────── Traces
                     ↓
            OpenTelemetry SDK
                     ↓
           OpenTelemetry Collector
                     ↓
                  Tempo
                     ↓
                 Grafana






                         ┌─────────────────────┐
                         │       Grafana       │
                         │  dashboards/explore │
                         └──────────┬──────────┘
                                    │
                         ┌──────────▼──────────┐
                         │      Prometheus     │
                         │  metrics + rules    │
                         └───────┬───────┬─────┘
                                 │       │
                   ┌─────────────┘       └──────────────┐
                   ▼                                    ▼
             Alertmanager                            Loki
             alerts/routing                         log storage
                   ▲                                    ▲
                   │                                    │
             PrometheusRules                         Promtail
                                                        │
                                                        ▼
                                                  Kubernetes logs