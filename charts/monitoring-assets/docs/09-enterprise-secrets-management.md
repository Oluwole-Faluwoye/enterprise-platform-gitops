# Stage E — Enterprise Secrets Management

# Overview

The previous stages of the Enterprise Platform focused on establishing a complete observability platform capable of monitoring the Kubernetes cluster, collecting application metrics, visualizing system health, and generating operational alerts.

At this point, the platform contains:

- Amazon EKS
- Argo CD
- GitOps deployment pipeline
- kube-prometheus-stack
- Grafana
- Prometheus
- Alertmanager
- Loki
- Promtail
- Enterprise Monitoring Assets
- Recording Rules
- Alert Rules

While the monitoring platform is now functionally complete, it still contains one major weakness commonly found in early Kubernetes environments:

**Application and infrastructure secrets are stored directly within configuration files.**

Although placeholder credentials are currently being used, this approach is not acceptable for production environments.

The objective of this stage is to eliminate every secret stored in Git and replace them with a centralized, secure, and automated secrets management solution.

---

# Why This Stage Is Necessary

Infrastructure as Code makes infrastructure reproducible.

GitOps makes deployments reproducible.

Neither of these technologies should be responsible for storing sensitive information.

Credentials such as:

- Database passwords
- SMTP passwords
- Grafana administrator passwords
- JWT signing keys
- OAuth secrets
- Slack webhooks
- API tokens
- AWS credentials

should never exist inside Git repositories.

Even private repositories should not be treated as secret stores.

A compromise of source control should never expose production credentials.

Instead, modern cloud-native platforms separate:

Infrastructure

↓

Configuration

↓

Secrets

Each layer has its own lifecycle and security controls.

---

# Current Architecture

The platform currently follows the architecture below.

```
Developer

↓

GitHub

↓

Argo CD

↓

Helm

↓

Kubernetes

↓

Applications
```

Configuration and secrets are currently mixed together inside Helm values files.

For example:

```
Grafana

↓

adminPassword

↓

Helm Values
```

This simplifies initial development but does not meet enterprise security standards.

---

# Target Architecture

After this stage, the platform architecture becomes:

```
Terraform

↓

AWS Secrets Manager

↓

External Secrets Operator

↓

ClusterSecretStore

↓

ExternalSecret

↓

Kubernetes Secret

↓

Deployment

↓

Container

↓

Application
```

Applications no longer receive credentials from Git.

Instead, they receive credentials from Kubernetes Secrets that are automatically synchronized from AWS Secrets Manager.

Git contains only references to secrets.

The actual secret values remain inside AWS.

---

# Why AWS Secrets Manager?

AWS Secrets Manager provides:

- Encrypted secret storage
- Automatic encryption using AWS KMS
- Fine-grained IAM permissions
- Secret rotation
- Version history
- Audit logging
- High availability
- Native AWS integration

Since the Enterprise Platform already runs entirely on AWS, AWS Secrets Manager is the natural choice.

---

# Why External Secrets Operator?

Applications running inside Kubernetes cannot read AWS Secrets Manager directly.

External Secrets Operator bridges this gap.

It continuously synchronizes secrets from AWS Secrets Manager into Kubernetes Secrets.

This removes the need for engineers to manually create Kubernetes Secrets.

Synchronization is automatic.

Whenever a secret changes in AWS, Kubernetes is updated automatically.

---

# Why ClusterSecretStore Instead of SecretStore?

External Secrets supports two methods of connecting Kubernetes to an external secret provider.

## SecretStore

A SecretStore exists inside a single namespace.

Example:

```
monitoring

↓

SecretStore
```

If another namespace also needs secrets:

```
auth

↓

SecretStore
```

Another SecretStore must be created.

This leads to duplicated configuration.

---

## ClusterSecretStore

A ClusterSecretStore exists once for the entire cluster.

```
ClusterSecretStore

↓

Monitoring Namespace

↓

Auth Namespace

↓

Argo CD Namespace

↓

Future Services
```

Every namespace can reference the same secure connection.

This significantly simplifies administration and scales much better as additional services are introduced.

For this reason, the Enterprise Platform adopts a ClusterSecretStore.

---

# Secrets Lifecycle

The complete lifecycle of a secret within the Enterprise Platform is shown below.

```
Terraform

↓

AWS Secrets Manager

↓

External Secrets Operator

↓

ClusterSecretStore

↓

ExternalSecret

↓

Kubernetes Secret

↓

Deployment

↓

Container

↓

Environment Variables

↓

Application
```

Each component has a clearly defined responsibility.

Terraform provisions AWS infrastructure.

AWS Secrets Manager stores encrypted credentials.

External Secrets synchronizes secrets into Kubernetes.

Applications consume standard Kubernetes Secrets without requiring knowledge of AWS.

---

# What Will Change

The following values currently stored in configuration files will be migrated.

## Grafana

Current:

```
adminPassword
```

Future:

```
grafana-admin-secret
```

---

## Alertmanager

Current:

SMTP placeholders

Future:

SMTP credentials stored in AWS Secrets Manager.

---

## Auth Service

Current:

JWT secrets stored in configuration.

Future:

JWT signing keys stored in AWS Secrets Manager.

---

## Database

Current:

Database password in Helm values.

Future:

Database password synchronized from AWS Secrets Manager.

---

## Future Platform Services

Future services will follow the same architecture.

Examples include:

- Redis
- RabbitMQ
- Kafka
- OAuth providers
- GitHub Tokens
- Docker Registry Credentials

Every secret follows the same lifecycle.

---

# Benefits

Moving secrets out of Git provides several operational advantages.

## Improved Security

Git repositories no longer contain sensitive information.

---

## Centralized Secret Management

All secrets are stored in one location.

---

## Secret Rotation

Secrets can be rotated without modifying application manifests.

---

## GitOps Compatibility

Git continues to describe infrastructure without exposing sensitive values.

---

## Easier Auditing

AWS provides complete audit trails for secret access.

---

## Reduced Operational Risk

Credentials cannot be accidentally committed to source control.

---

# Deliverables

This stage introduces the following platform components.

```
External Secrets Operator

ClusterSecretStore

AWS Secrets Manager

ExternalSecret Resources

Grafana Secret

Alertmanager Secret

Auth Service Secret
```

All future applications deployed onto the Enterprise Platform will consume secrets using the same standardized process.

---

# Relationship to Previous Stage

The previous stage focused on observability.

Specifically:

- Recording Rules
- Alert Rules
- Alertmanager
- Grafana Provisioning
- Dashboard Provisioning

Those components provide visibility into the health of the platform.

The current stage focuses on securing the platform itself.

Rather than adding new monitoring capabilities, this stage improves the operational maturity of the platform by introducing enterprise-grade secrets management.

---

# Relationship to Future Stages

Completing this stage enables the remaining platform capabilities.

Future stages will build on this foundation.

These include:

- Grafana authentication
- SMTP notifications
- Slack notifications
- Spring Boot application secrets
- OAuth integrations
- Database credentials
- Production hardening

Without centralized secrets management, these capabilities would require storing sensitive information in Git.

By completing this stage first, every future service automatically benefits from secure credential management.

---

# Summary

The Enterprise Platform has successfully evolved from a basic Kubernetes deployment into a GitOps-driven observability platform.

The next phase focuses on security.

By integrating AWS Secrets Manager with External Secrets Operator, the platform removes all sensitive credentials from source control and establishes a centralized, automated, and scalable secrets management architecture.

This approach aligns with modern cloud-native security practices and ensures that every future application deployed to the platform consumes credentials securely while remaining fully compatible with GitOps and Infrastructure as Code principles.