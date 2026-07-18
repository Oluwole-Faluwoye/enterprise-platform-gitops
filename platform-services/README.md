Objective

Right now we have:

AWS Secrets Manager

↓

External Secrets Operator

The operator still doesn't know how to connect to AWS.

We need to create a ClusterSecretStore.

Think of it as the operator's connection configuration.

Without it:

External Secrets

↓

???

↓

AWS

With it:

AWS Secrets Manager
        │
        ▼
ClusterSecretStore
        │
        ▼
External Secrets Operator
        │
        ▼
ExternalSecret
        │
        ▼
Kubernetes Secret