# Secrets Management Architecture

**Document Version:** 1.0

**Repository:** Enterprise Platform

**Component:** Enterprise Secrets Management

---

# Related Documents

Infrastructure

- 03-module-design.md
- 04-secrets-management.md
- 05-irsa.md

GitOps

- 15-external-secrets-operator.md
- 16-cluster-secret-store.md
- 17-external-secrets.md

Platform

- 01-cluster-overview.md
- 08-observability-architecture.md

---

# Overview

Every modern cloud platform depends on secrets.

Examples include:

- Database credentials
- SMTP credentials
- OAuth client secrets
- JWT signing keys
- API keys
- TLS certificates
- Third-party integration tokens

Managing these securely is one of the most important responsibilities of a Platform Engineering team.

The Enterprise Platform follows an enterprise-grade secrets management strategy based on:

- AWS Secrets Manager
- Terraform
- IAM Roles for Service Accounts (IRSA)
- External Secrets Operator
- Argo CD
- Kubernetes Secrets

The objective is simple:

> Secrets should never be stored inside Git repositories or manually created inside Kubernetes.

---

# Design Goals

The platform was designed around several principles.

## Security

Secrets should never exist inside source control.

---

## Automation

Secrets should synchronize automatically.

---

## Least Privilege

Applications should only receive the credentials they require.

---

## GitOps

Configuration belongs in Git.

Secret values do not.

---

## Scalability

The same architecture should support:

- Development
- Staging
- Production

without redesign.

---

# Architecture

```
                     Terraform
                         │
                         │
      ┌──────────────────┴──────────────────┐
      │                                     │
AWS Secrets Manager                 IAM + IRSA
      │                                     │
      └──────────────────┬──────────────────┘
                         │
                         ▼
                External Secrets Operator
                         │
                         ▼
                ClusterSecretStore
                         │
                         ▼
                  ExternalSecret
                         │
                         ▼
                Kubernetes Secret
                         │
                         ▼
                    Application
```

---

# Component Responsibilities

Each component has exactly one responsibility.

## Terraform

Responsible for:

- AWS Secrets
- IAM Roles
- IAM Policies
- OIDC
- IRSA

Terraform does **not** create Kubernetes Secrets.

---

## AWS Secrets Manager

Acts as the authoritative source of all secrets.

Responsibilities:

- Encryption
- Versioning
- Rotation
- Auditing
- Secure storage

---

## IAM Roles for Service Accounts (IRSA)

Provides secure authentication between Kubernetes and AWS.

No AWS Access Keys are required.

---

## External Secrets Operator

Synchronizes secrets from AWS Secrets Manager into Kubernetes.

---

## ClusterSecretStore

Defines how Kubernetes connects to AWS.

---

## ExternalSecret

Defines which AWS secrets should be synchronized.

---

## Kubernetes Secret

Provides applications with credentials in the format Kubernetes expects.

Applications continue consuming normal Kubernetes Secrets without any awareness of AWS.

---

# End-to-End Secret Lifecycle

The complete lifecycle is shown below.

## Step 1

Terraform creates a secret.

↓

AWS Secrets Manager

---

## Step 2

Terraform creates IAM Role.

↓

IRSA

---

## Step 3

Terraform creates IAM Policy.

↓

Least Privilege

---

## Step 4

Argo CD installs External Secrets Operator.

---

## Step 5

Argo CD creates ClusterSecretStore.

---

## Step 6

Argo CD deploys ExternalSecret.

---

## Step 7

Operator authenticates with AWS.

---

## Step 8

Operator retrieves secret.

---

## Step 9

Kubernetes Secret is created.

---

## Step 10

Application starts.

---

# Authentication Flow

The platform uses IAM Roles for Service Accounts.

```
Application

↓

ServiceAccount

↓

OIDC Provider

↓

IAM Role

↓

Temporary Credentials

↓

AWS Secrets Manager
```

No static credentials exist.

---

# Secret Flow

```
Terraform

↓

AWS Secrets Manager

↓

External Secrets Operator

↓

ExternalSecret

↓

Kubernetes Secret

↓

Application
```

---

# Why Kubernetes Secrets Still Exist

Applications expect Kubernetes Secrets.

Examples include:

- Deployment manifests
- Helm charts
- Spring Boot
- Grafana
- Alertmanager

Instead of modifying every application to query AWS directly, Kubernetes Secrets act as a compatibility layer.

Applications remain cloud-agnostic.

---

# Why Applications Never Read AWS Directly

Direct AWS integration introduces:

- Additional SDK dependencies
- IAM complexity
- Cloud-specific code
- Harder local development
- Increased application responsibility

Instead:

Applications

↓

Kubernetes Secret

↓

Platform

↓

AWS

This keeps applications simple and portable.

---

# Security Model

The platform follows several enterprise security principles.

## Principle 1

AWS Secrets Manager is the source of truth.

---

## Principle 2

Git never stores secrets.

---

## Principle 3

Applications never receive AWS credentials.

---

## Principle 4

Authentication uses temporary credentials.

---

## Principle 5

IAM Policies enforce least privilege.

---

## Principle 6

Every secret is auditable.

---

# Secret Rotation

Secret rotation becomes significantly easier.

Old workflow:

Update Secret

↓

Update Kubernetes

↓

Restart Application

↓

Hope Everything Works

---

New workflow:

Rotate Secret

↓

AWS Secrets Manager

↓

External Secrets Operator

↓

Kubernetes Secret Updated

↓

Application Uses Updated Secret

Minimal manual intervention is required.

---

# GitOps Integration

Git stores:

- Helm Charts
- ExternalSecrets
- ClusterSecretStore
- Platform Configuration

Git does not store:

- Passwords
- Tokens
- Keys
- Certificates

This separation keeps repositories secure while maintaining full declarative infrastructure.

---

# Monitoring

The platform should monitor:

- External Secrets synchronization status
- Secret refresh failures
- AWS API errors
- Authentication failures
- Secret age
- Secret rotation events

Future Grafana dashboards can visualize these metrics.

---

# Disaster Recovery

Recovery becomes straightforward.

Scenario:

Cluster destroyed.

Recovery process:

Recreate Cluster

↓

Argo CD

↓

External Secrets Operator

↓

ClusterSecretStore

↓

ExternalSecrets

↓

Secrets synchronized from AWS

↓

Applications start

No manual secret recreation is required.

---

# Auditing

Auditing occurs at multiple layers.

AWS CloudTrail records:

- Secret access
- Secret updates
- IAM activity

Kubernetes records:

- ExternalSecret status
- Operator events

Git records:

- Configuration changes
- Secret mappings

Together these provide end-to-end traceability.

---

# Enterprise Best Practices

The Enterprise Platform follows these practices.

- Never commit secrets to Git.
- Use AWS Secrets Manager as the source of truth.
- Authenticate using IRSA.
- Use ClusterSecretStore instead of duplicate SecretStores.
- Create one ExternalSecret per application or component.
- Grant least privilege IAM permissions.
- Rotate secrets regularly.
- Audit secret access.
- Monitor synchronization health.
- Keep infrastructure and Kubernetes responsibilities separate.

---

# Future Improvements

As the platform evolves, the following enhancements can be introduced.

## Secret Rotation

Automatic rotation using AWS Secrets Manager.

---

## Multiple AWS Accounts

Environment-specific secrets.

---

## Multi-Region

Replicated secrets.

---

## Vault Support

HashiCorp Vault integration.

---

## Azure Key Vault

Alternative cloud provider.

---

## Google Secret Manager

Multi-cloud support.

---

## Dynamic Database Credentials

Short-lived credentials generated on demand.

---

## Certificate Management

Integration with cert-manager and External Secrets.

---

# Benefits

The architecture provides:

- Centralized secret management
- Secure authentication
- Automated synchronization
- GitOps compatibility
- Environment consistency
- Improved security
- Easier disaster recovery
- Reduced operational effort
- Better scalability
- Cleaner application architecture

---

# Complete Platform Flow

```
                 Developer

                     │

                     ▼

               Git Repository

                     │

         ┌───────────┴───────────┐

         ▼                       ▼

Terraform                  Argo CD

         │                       │

         ▼                       ▼

AWS Secrets Manager    External Secrets Operator

         │                       │

         └───────────┬───────────┘

                     ▼

            ClusterSecretStore

                     ▼

             ExternalSecret

                     ▼

           Kubernetes Secret

                     ▼

               Application
```

---

# Summary

The Enterprise Platform implements a modern, enterprise-grade secrets management architecture based on Infrastructure as Code, GitOps, and cloud-native security principles.

Terraform provisions the AWS infrastructure, IAM resources, and Secrets Manager.

Argo CD deploys the External Secrets Operator and Kubernetes resources.

IRSA provides secure, temporary authentication without static credentials.

The External Secrets Operator synchronizes secrets from AWS Secrets Manager into Kubernetes.

Applications consume standard Kubernetes Secrets without requiring any AWS-specific logic.

This layered approach delivers a secure, scalable, and maintainable secrets management solution that aligns with enterprise platform engineering best practices while keeping responsibilities clearly separated across infrastructure, Kubernetes, and applications.