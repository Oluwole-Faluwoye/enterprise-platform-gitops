# External Secrets Operator

**Document Version:** 1.0

**Repository:** Enterprise Platform GitOps

**Component:** External Secrets Operator

**Related Documents**

- 01-cluster-overview.md
- 07-monitoring-foundation.md
- 08-observability-architecture.md
- 16-cluster-secret-store.md
- 17-external-secrets.md
- 18-secrets-management.md

---

# Overview

Modern cloud-native applications rely on sensitive information such as:

- Database credentials
- JWT signing keys
- API keys
- SMTP credentials
- OAuth secrets
- Cloud provider credentials
- Third-party integration tokens

Historically, many Kubernetes deployments stored these values directly inside Kubernetes Secrets.

Although Kubernetes Secrets are base64 encoded, they are **not encrypted by default** and are intended only as an in-cluster mechanism for delivering sensitive configuration to workloads.

From an enterprise security perspective, Kubernetes should **not** be considered the source of truth for secrets.

Instead, secrets should be managed by a dedicated secrets management system.

For the Enterprise Platform, AWS Secrets Manager is the system of record.

The responsibility of the External Secrets Operator is to synchronize secrets stored in AWS Secrets Manager into Kubernetes Secrets so that applications can consume them without ever storing sensitive values in Git.

---

# Purpose

The External Secrets Operator provides a secure bridge between AWS Secrets Manager and Kubernetes.

Rather than manually creating Kubernetes Secrets, the operator continuously synchronizes secrets from AWS.

This enables:

- GitOps-friendly secret management
- Secure credential storage
- Automated secret synchronization
- Secret rotation support
- Reduced operational overhead
- Elimination of hardcoded credentials

---

# Why We Need It

Without the External Secrets Operator, the workflow would typically look like this:

Developer

↓

Creates Kubernetes Secret

↓

Applies Secret to Cluster

↓

Application Reads Secret

Problems with this approach include:

- Manual secret creation
- Secret duplication
- Human error
- Difficult secret rotation
- Credentials living outside a centralized vault
- Potential exposure in CI/CD pipelines

---

With External Secrets:

AWS Secrets Manager

↓

External Secrets Operator

↓

Kubernetes Secret

↓

Application

Applications never communicate directly with AWS Secrets Manager.

Instead, they continue reading standard Kubernetes Secrets while the operator handles synchronization automatically.

---

# Architecture

## High-Level Architecture

                    AWS
                     │
                     │
             Secrets Manager
                     │
                     │
             ClusterSecretStore
                     │
                     │
      External Secrets Operator
                     │
                     │
            ExternalSecret CRD
                     │
                     │
          Kubernetes Secret
                     │
                     │
                Application

---

# Responsibilities

The External Secrets Operator is responsible for:

- Authenticating with AWS
- Reading secrets from AWS Secrets Manager
- Synchronizing secrets into Kubernetes
- Monitoring secret changes
- Updating Kubernetes Secrets automatically
- Reporting synchronization status

It is **not** responsible for:

- Creating AWS Secrets
- Rotating credentials
- Encrypting AWS Secrets
- Managing IAM permissions
- Creating application-specific configuration

Those responsibilities belong to Terraform and AWS.

---

# Why AWS Secrets Manager?

AWS Secrets Manager provides:

- Encryption at rest
- Fine-grained IAM permissions
- Secret versioning
- Automatic rotation support
- Audit logging through CloudTrail
- High availability
- Native AWS integration

This makes it the authoritative source for all sensitive configuration within the Enterprise Platform.

---

# Why Not Store Secrets in Git?

Git repositories are designed for source code—not credentials.

Even encrypted secret solutions such as Sealed Secrets or SOPS require careful key management.

Using AWS Secrets Manager provides:

- Centralized secret storage
- IAM-based access control
- Rotation support
- Native auditing
- Reduced operational complexity

No passwords or API keys are committed to Git.

---

# Authentication Using IRSA

The External Secrets Operator authenticates with AWS using IAM Roles for Service Accounts (IRSA).

The authentication flow is:

External Secrets Pod

↓

Kubernetes ServiceAccount

↓

OIDC Provider

↓

IAM Role

↓

Temporary AWS Credentials

↓

AWS Secrets Manager

No static AWS access keys are stored inside Kubernetes.

This follows AWS security best practices.

---

# Integration with Terraform

Terraform provisions the infrastructure required for secret synchronization.

Terraform creates:

- AWS Secrets Manager secrets
- IAM policy
- IAM role
- OIDC trust relationship
- IRSA configuration

Terraform intentionally does **not** create Kubernetes Secrets.

Instead, Kubernetes secrets are created dynamically by the External Secrets Operator.

---

# Integration with Argo CD

Argo CD installs the External Secrets Operator using the official Helm chart.

GitOps Repository

↓

Argo CD

↓

Helm Chart

↓

External Secrets Operator

This ensures the operator is deployed consistently across environments.

---

# Synchronization Workflow

The synchronization process follows these steps:

1. Secret exists in AWS Secrets Manager.
2. External Secrets Operator authenticates using IRSA.
3. Operator queries AWS Secrets Manager.
4. Secret value is retrieved.
5. Kubernetes Secret is created or updated.
6. Applications consume the Kubernetes Secret.
7. Secret updates are synchronized automatically.

No manual intervention is required.

---

# Enterprise Design Principles

The Enterprise Platform follows several important design principles:

## Single Source of Truth

AWS Secrets Manager is the authoritative location for all secrets.

---

## Separation of Responsibilities

Terraform

↓

Creates Infrastructure

External Secrets Operator

↓

Synchronizes Secrets

Applications

↓

Consume Secrets

Each component has a clearly defined responsibility.

---

## Least Privilege

The External Secrets IAM role receives permission only to read the specific secrets required by the platform.

Permissions are scoped to individual secret ARNs rather than using wildcard access.

---

## GitOps Compatibility

Git contains:

- Infrastructure definitions
- Helm charts
- Kubernetes manifests

Git never contains:

- Passwords
- Tokens
- API keys
- Certificates
- SMTP credentials

---

# Security Considerations

The platform follows several security best practices:

- No static AWS credentials
- IAM Roles for Service Accounts (IRSA)
- Least privilege IAM policies
- Centralized secret management
- AWS-managed encryption
- Git contains no secret values

This significantly reduces the attack surface.

---

# Benefits

Using the External Secrets Operator provides:

- Centralized secret management
- Automatic synchronization
- Secret rotation support
- Reduced manual operations
- Improved security
- GitOps compatibility
- Consistent deployments
- Environment independence

---

# Validation

After deployment, verify the operator:

```bash
kubectl get pods -n external-secrets
```

Expected:

```
external-secrets-xxxxx   Running
```

---

Verify CRDs:

```bash
kubectl get crds | grep external-secrets
```

Expected:

```
clustersecretstores.external-secrets.io
externalsecrets.external-secrets.io
secretstores.external-secrets.io
```

---

Verify Argo CD:

```bash
kubectl get applications -n argocd
```

Expected:

```
external-secrets
```

---

# Troubleshooting

## Pod CrashLoopBackOff

Possible causes:

- Missing IAM role
- Incorrect IRSA annotation
- Helm values misconfiguration

---

## Authentication Failure

Possible causes:

- Incorrect OIDC provider
- Trust policy mismatch
- Missing IAM permissions

---

## Secret Not Synchronizing

Possible causes:

- Incorrect ClusterSecretStore
- Missing AWS Secret
- Incorrect region
- Incorrect secret name

---

## Access Denied

Verify:

- IAM Role
- IAM Policy
- Secret ARN permissions

---

# Future Enhancements

Future platform improvements include:

- Automatic secret rotation
- Multi-account secret synchronization
- Cross-region secret replication
- Secret version monitoring
- Certificate synchronization
- HashiCorp Vault integration
- Azure Key Vault support
- Google Secret Manager support

---

# Summary

The External Secrets Operator is a foundational component of the Enterprise Platform.

It enables secure, automated, and GitOps-compatible secret management by synchronizing secrets from AWS Secrets Manager into Kubernetes using IAM Roles for Service Accounts (IRSA).

This architecture removes sensitive information from source control, centralizes secret management, supports automated synchronization, and provides a scalable foundation for enterprise Kubernetes workloads.