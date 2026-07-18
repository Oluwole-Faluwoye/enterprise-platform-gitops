# ClusterSecretStore

**Document Version:** 1.0

**Repository:** Enterprise Platform GitOps

**Component:** ClusterSecretStore

**Related Documents**

- 01-cluster-overview.md
- 15-external-secrets-operator.md
- 17-external-secrets.md
- 18-secrets-management.md
- 03-module-design.md (Terraform)
- 05-irsa.md (Terraform)

---

# Overview

The External Secrets Operator is responsible for synchronizing secrets from external secret providers into Kubernetes.

However, before it can retrieve any secrets, it must know:

- Which provider to connect to
- Which AWS Region to use
- How to authenticate
- Which credentials to use

This configuration is defined using a **ClusterSecretStore**.

A ClusterSecretStore acts as the bridge between Kubernetes and an external secrets provider.

For the Enterprise Platform, AWS Secrets Manager is configured as the external provider.

---

# Purpose

The purpose of the ClusterSecretStore is to define a reusable connection to AWS Secrets Manager that can be shared across the entire Kubernetes cluster.

Instead of every application configuring its own AWS connection, all workloads reference the same centralized store.

This provides:

- Centralized authentication
- Standardized configuration
- Reduced duplication
- Easier maintenance
- Improved security
- Better scalability

---

# Why Do We Need a ClusterSecretStore?

Without a ClusterSecretStore, every application would need to define:

- AWS Region
- Authentication mechanism
- Secret provider
- IAM configuration

For ten applications, that means maintaining ten nearly identical configurations.

This creates unnecessary duplication and increases operational risk.

Instead, the Enterprise Platform defines one shared ClusterSecretStore.

Applications simply reference it when requesting secrets.

---

# SecretStore vs ClusterSecretStore

The External Secrets Operator provides two types of secret stores.

## SecretStore

A SecretStore is **namespace-scoped**.

It can only be used by resources within the same namespace.

Example:

```
payments namespace

└── SecretStore
```

Only workloads inside the `payments` namespace can use it.

---

## ClusterSecretStore

A ClusterSecretStore is **cluster-scoped**.

It can be referenced from any namespace.

Example:

```
ClusterSecretStore

├── monitoring
├── auth-service
├── payments
├── inventory
└── reporting
```

Every application in the cluster can use the same centralized configuration.

---

# Why We Chose ClusterSecretStore

The Enterprise Platform is designed as a shared platform supporting multiple services.

Using ClusterSecretStore provides several advantages:

- One AWS connection configuration
- Consistent authentication
- Easier onboarding of new services
- Simplified GitOps management
- Reduced configuration drift

For enterprise platforms, ClusterSecretStore is generally the preferred approach.

---

# Architecture

The complete architecture is shown below.

```
                 AWS
                  │
                  │
          Secrets Manager
                  │
                  │
          IAM Permissions
                  │
                  │
              IRSA Role
                  │
                  │
      External Secrets Operator
                  │
                  │
        ClusterSecretStore
                  │
                  │
         ExternalSecret CRD
                  │
                  │
         Kubernetes Secret
                  │
                  │
            Application Pods
```

---

# Authentication Flow

One of the most important aspects of the platform is authentication.

No AWS Access Keys are stored anywhere inside Kubernetes.

Authentication occurs automatically using IAM Roles for Service Accounts (IRSA).

The process is:

1. External Secrets Operator runs inside Kubernetes.
2. The operator uses a Kubernetes ServiceAccount.
3. The ServiceAccount is annotated with an IAM Role.
4. Kubernetes issues an OIDC token.
5. AWS validates the token.
6. AWS returns temporary credentials.
7. The operator reads secrets from AWS Secrets Manager.

This process is completely automatic.

---

# Why IRSA?

IRSA eliminates the need for:

- AWS Access Keys
- AWS Secret Keys
- Static credentials
- Long-lived IAM users

Instead, workloads receive temporary credentials only when required.

Benefits include:

- Reduced credential exposure
- Automatic credential rotation
- Improved auditing
- Least privilege access
- Native AWS integration

---

# Configuration

The ClusterSecretStore defines:

- AWS Provider
- AWS Region
- Authentication Method
- ServiceAccount

Example architecture:

```
ClusterSecretStore

Provider
    │
    ├── AWS Secrets Manager
    │
Region
    │
    ├── us-east-1
    │
Authentication
    │
    ├── JWT
    │
ServiceAccount
    │
    └── external-secrets
```

Applications do not need to know any of this information.

---

# How Applications Use the Store

Applications never communicate directly with AWS Secrets Manager.

Instead, an ExternalSecret references the ClusterSecretStore.

Example:

```
ExternalSecret

↓

ClusterSecretStore

↓

AWS Secrets Manager

↓

Kubernetes Secret

↓

Application
```

The application simply consumes a standard Kubernetes Secret.

---

# Integration with Terraform

Terraform provisions the infrastructure required for the ClusterSecretStore.

Terraform creates:

- AWS Secrets Manager secrets
- IAM Policy
- IAM Role
- OIDC Provider
- IRSA trust relationship

Terraform intentionally does **not** create the ClusterSecretStore itself.

The ClusterSecretStore is a Kubernetes resource and is managed using GitOps.

This separation ensures:

- Infrastructure remains in Terraform
- Kubernetes resources remain in GitOps
- Clear ownership boundaries
- Easier upgrades

---

# Integration with Argo CD

The ClusterSecretStore is deployed by Argo CD using the custom platform chart.

Deployment flow:

```
Git Repository

↓

Argo CD

↓

Helm Chart

↓

ClusterSecretStore

↓

External Secrets Operator
```

Every cluster receives an identical configuration.

---

# Security Model

The ClusterSecretStore itself does **not** contain any secrets.

It contains only connection information.

Security is enforced through:

- IAM Role
- IRSA
- AWS IAM Policy
- OIDC Trust Relationship

The actual secret values remain inside AWS Secrets Manager.

This minimizes the risk of credential exposure inside Kubernetes.

---

# Enterprise Design Principles

The ClusterSecretStore follows several important design principles.

## Centralized Configuration

One connection configuration.

Many applications.

---

## Reusability

Every namespace can use the same store.

---

## Least Privilege

Access is granted through IAM Roles.

Applications never receive unnecessary permissions.

---

## Separation of Responsibilities

Terraform

↓

Creates AWS Infrastructure

Argo CD

↓

Deploys Kubernetes Resources

External Secrets Operator

↓

Synchronizes Secrets

Applications

↓

Consume Secrets

Each component has a single responsibility.

---

# Benefits

Using a ClusterSecretStore provides:

- Reusable configuration
- Reduced duplication
- Easier onboarding
- Consistent authentication
- Simpler maintenance
- Better scalability
- Improved security
- GitOps compatibility

---

# Validation

After deployment, verify the ClusterSecretStore.

List all ClusterSecretStores:

```bash
kubectl get clustersecretstores
```

Expected output:

```
NAME

aws-secretsmanager
```

---

Describe the ClusterSecretStore:

```bash
kubectl describe clustersecretstore aws-secretsmanager
```

Expected status:

```
Ready=True
```

---

Verify the External Secrets Operator:

```bash
kubectl get pods -n external-secrets
```

---

Verify the ServiceAccount:

```bash
kubectl get sa -n external-secrets
```

---

Verify the IAM annotation:

```bash
kubectl describe sa external-secrets -n external-secrets
```

The ServiceAccount should contain the IAM Role annotation created for IRSA.

---

# Troubleshooting

## ClusterSecretStore Not Ready

Possible causes:

- Incorrect AWS Region
- Missing IAM Role
- Incorrect ServiceAccount
- Invalid IRSA configuration

---

## Authentication Failed

Verify:

- OIDC Provider
- IAM Trust Policy
- ServiceAccount annotation

---

## Access Denied

Verify:

- IAM Policy
- Secret ARN permissions
- Secrets Manager access

---

## Secret Synchronization Failed

Verify:

- Secret exists in AWS Secrets Manager
- Secret name matches
- ClusterSecretStore is Ready
- External Secrets Operator is running

---

# Best Practices

For production environments:

- Use one ClusterSecretStore per cloud provider.
- Restrict IAM permissions to required secret ARNs.
- Use IRSA instead of static credentials.
- Keep AWS Secrets Manager as the system of record.
- Manage the ClusterSecretStore through GitOps.
- Never store secrets inside Git.
- Audit IAM permissions regularly.
- Monitor External Secrets synchronization status.

---

# Future Enhancements

Future improvements may include:

- Multi-region secret replication
- Cross-account secret access
- Multiple ClusterSecretStores
- HashiCorp Vault integration
- Azure Key Vault integration
- Google Secret Manager integration
- Automatic secret rotation monitoring

---

# Summary

The ClusterSecretStore is the central configuration object that allows the External Secrets Operator to communicate securely with AWS Secrets Manager.

It provides a reusable, cluster-wide connection that all applications can share, eliminating duplicated configuration while enforcing consistent authentication and security.

Combined with IAM Roles for Service Accounts (IRSA), AWS Secrets Manager, Terraform, and Argo CD, the ClusterSecretStore enables a secure, automated, and GitOps-driven secrets management architecture suitable for enterprise Kubernetes platforms.