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