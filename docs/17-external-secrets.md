# ExternalSecret

**Document Version:** 1.0

**Repository:** Enterprise Platform GitOps

**Component:** ExternalSecret

**Related Documents**

- 15-external-secrets-operator.md
- 16-cluster-secret-store.md
- 18-secrets-management.md
- 05-irsa.md (Terraform)
- 03-module-design.md (Terraform)

---

# Overview

The External Secrets Operator provides the mechanism for synchronizing secrets from an external provider into Kubernetes.

However, the operator itself does not know **which secrets** should be synchronized.

This responsibility belongs to the **ExternalSecret** resource.

An ExternalSecret defines:

- Which secret should be retrieved
- Which SecretStore or ClusterSecretStore to use
- How often synchronization should occur
- What the resulting Kubernetes Secret should be named
- Which keys should be synchronized

It acts as the link between AWS Secrets Manager and a Kubernetes Secret.

---

# Purpose

The purpose of an ExternalSecret is to automate the creation and maintenance of Kubernetes Secrets.

Instead of manually creating Kubernetes Secrets, platform engineers simply define an ExternalSecret resource in Git.

The External Secrets Operator continuously reconciles that resource and ensures Kubernetes always contains an up-to-date Secret.

---

# Why ExternalSecrets Exist

Without ExternalSecrets, secret management would require manual intervention.

Typical workflow:

Developer

↓

Create Kubernetes Secret

↓

Apply Secret

↓

Application Reads Secret

Problems:

- Manual updates
- Human error
- Difficult rotation
- Configuration drift
- Multiple copies of the same secret

---

With ExternalSecrets:

AWS Secrets Manager

↓

ExternalSecret

↓

External Secrets Operator

↓

Kubernetes Secret

↓

Application

The Kubernetes Secret becomes a synchronized copy of the AWS secret.

---

# Architecture

Complete flow:

```
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
          ExternalSecret
                  │
                  │
       Kubernetes Secret
                  │
                  │
           Application Pod
```

---

# ExternalSecret Responsibilities

An ExternalSecret tells the operator:

- Which provider to use
- Which ClusterSecretStore to use
- Which AWS Secret to retrieve
- Which keys to synchronize
- Target Kubernetes Secret name
- Refresh interval

It does **not**:

- Authenticate with AWS
- Store credentials
- Read AWS directly

Those responsibilities belong to the External Secrets Operator.

---

# Synchronization Lifecycle

The synchronization process follows several stages.

## Stage 1

Developer creates an ExternalSecret.

↓

## Stage 2

Argo CD deploys the resource.

↓

## Stage 3

External Secrets Operator detects the new resource.

↓

## Stage 4

Operator authenticates using IRSA.

↓

## Stage 5

Operator queries AWS Secrets Manager.

↓

## Stage 6

Secret values are retrieved.

↓

## Stage 7

Operator creates a Kubernetes Secret.

↓

## Stage 8

Applications consume the Kubernetes Secret.

This process is completely automated.

---

# Refresh Process

ExternalSecrets continuously reconcile with AWS.

If a secret changes inside AWS Secrets Manager:

AWS Secret Updated

↓

External Secrets detects change

↓

Kubernetes Secret Updated

↓

Application continues using updated Secret

No manual synchronization is required.

---

# Refresh Interval

Each ExternalSecret defines a refresh interval.

Example:

```
refreshInterval: 1h
```

This tells the operator to check AWS Secrets Manager every hour.

Choosing an appropriate interval depends on:

- Secret rotation frequency
- Application requirements
- AWS API usage
- Operational requirements

---

# Secret Mapping

AWS Secrets may contain multiple values.

Example:

```
AWS Secret

username

password

endpoint
```

An ExternalSecret can map all of them into one Kubernetes Secret.

Result:

```
Kubernetes Secret

username

password

endpoint
```

This allows applications to continue using standard Kubernetes Secret references.

---

# Integration with Applications

Applications never communicate directly with AWS.

Instead:

Application

↓

Kubernetes Secret

↓

ExternalSecret

↓

AWS Secrets Manager

This abstraction allows applications to remain cloud-agnostic.

---

# Integration with Argo CD

ExternalSecrets are stored in Git.

Git Repository

↓

Argo CD

↓

ExternalSecret

↓

External Secrets Operator

↓

Kubernetes Secret

Git remains the source of truth for configuration while AWS remains the source of truth for secret values.

---

# Integration with Terraform

Terraform provisions:

- AWS Secrets Manager
- IAM Roles
- IRSA
- IAM Policies

Terraform does **not** create ExternalSecrets.

ExternalSecrets belong to Kubernetes and are managed entirely through GitOps.

This separation follows clear ownership boundaries.

---

# Enterprise Design Principles

## Infrastructure as Code

Terraform provisions AWS resources.

---

## GitOps

Argo CD manages Kubernetes resources.

---

## Secret Management

AWS Secrets Manager stores secret values.

---

## Secret Synchronization

External Secrets Operator synchronizes secrets.

---

## Application Consumption

Applications consume Kubernetes Secrets.

Each layer has a clearly defined responsibility.

---

# Security Considerations

ExternalSecrets do not contain secret values.

They contain only references.

Example:

```
AWS Secret Name

↓

Target Secret Name

↓

Keys
```

Actual credentials never appear inside Git.

This greatly reduces the risk of accidental credential exposure.

---

# Advantages

ExternalSecrets provide:

- Automatic synchronization
- GitOps compatibility
- Secret rotation support
- Reduced operational effort
- Consistent deployments
- Environment independence
- Simplified application configuration

---

# Validation

List ExternalSecrets:

```bash
kubectl get externalsecrets -A
```

Describe one:

```bash
kubectl describe externalsecret <name> -n <namespace>
```

Verify synchronized Kubernetes Secret:

```bash
kubectl get secret -n <namespace>
```

View synchronization status:

```bash
kubectl describe externalsecret <name>
```

Expected:

```
Ready=True

Secret Synced
```

---

# Troubleshooting

## Secret Not Created

Verify:

- ExternalSecret exists
- ClusterSecretStore is Ready
- AWS Secret exists

---

## Secret Not Updating

Verify:

- refreshInterval
- Operator logs
- IAM permissions

---

## Access Denied

Verify:

- IAM Policy
- IRSA Role
- Secret ARN permissions

---

## SecretStore Not Found

Verify:

- ClusterSecretStore name
- Namespace
- Argo CD synchronization

---

# Best Practices

Use one ExternalSecret per application or logical component.

Examples:

- Grafana
- Alertmanager
- Auth Service
- PostgreSQL
- Redis

Keep each ExternalSecret focused on a single responsibility.

Avoid creating one large ExternalSecret for the entire platform.

---

# Enterprise Workflow

Developer

↓

Terraform provisions infrastructure

↓

AWS Secret created

↓

Git updated with ExternalSecret

↓

Argo CD synchronizes

↓

Operator retrieves secret

↓

Kubernetes Secret created

↓

Application starts

No manual Kubernetes Secret creation occurs.

---

# Future Enhancements

Future improvements may include:

- Automatic secret rotation notifications
- Secret synchronization metrics
- Secret expiration monitoring
- Cross-region synchronization
- Multi-cloud secret providers
- Dynamic database credentials
- Certificate synchronization

---

# Summary

ExternalSecrets define **which secrets** should be synchronized from AWS Secrets Manager into Kubernetes.

They act as declarative synchronization instructions for the External Secrets Operator.

By separating secret values from application configuration, the Enterprise Platform achieves a secure, automated, GitOps-driven approach to secrets management that scales cleanly across multiple services and environments.