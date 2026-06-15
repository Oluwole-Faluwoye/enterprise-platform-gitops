# ArgoCD Repository Authentication

## Overview

ArgoCD continuously monitors Git repositories and reconciles Kubernetes resources to match the desired state stored in Git.

For this platform, the GitOps repository serves as the source of truth for all Kubernetes deployments.

Repository:

enterprise-platform-gitops

ArgoCD must independently authenticate to this repository.

Repository access granted to Jenkins does not automatically grant repository access to ArgoCD.

These systems operate independently and require separate authentication mechanisms.

---

# Repository Access Model

The platform uses SSH-based repository authentication.

Architecture:

GitHub Repository
↓
SSH Deploy Key
↓
ArgoCD Repository Secret
↓
ArgoCD Repo Server
↓
Kubernetes Cluster

ArgoCD periodically retrieves repository contents and compares them against current cluster state.

Any detected drift is automatically reconciled.

---

# Why SSH Authentication?

Several authentication methods exist:

* HTTPS with Personal Access Tokens
* SSH Deploy Keys
* GitHub App Authentication

SSH authentication was selected because it:

* Mirrors enterprise GitOps implementations
* Avoids Personal Access Token management
* Provides cryptographic authentication
* Supports repository-scoped permissions
* Demonstrates secure machine-to-machine communication

---

# Public Repository vs Private Repository

The repository may remain public for portfolio visibility.

However, the platform is intentionally designed as though the repository were private.

This ensures:

* Production-ready architecture
* Enterprise-aligned security practices
* Easier future migration to private repositories

The same authentication workflow remains in place regardless of repository visibility.

---

# Why Secrets Are Not Stored in Git

Private keys must never be committed to source control.

For this platform:

* The ArgoCD private key is stored in AWS Secrets Manager
* Jenkins retrieves the secret at runtime
* A repository secret is generated dynamically
* ArgoCD consumes the generated secret

Architecture:

AWS Secrets Manager
↓
Jenkins Pipeline
↓
Repository Secret Creation
↓
ArgoCD Repo Server

Benefits:

* No secret exposure in Git
* Centralized secret management
* Easier key rotation
* Improved auditability
* Reduced operational risk

---

# Repository Secret Architecture

ArgoCD repositories are registered using Kubernetes Secrets.

Secret Name:

enterprise-platform-gitops

Namespace:

argocd

Label:

argocd.argoproj.io/secret-type: repository

Template File:

platform-services/argocd-repository-secret.yaml

Template:

apiVersion: v1
kind: Secret

metadata:
name: enterprise-platform-gitops
namespace: argocd

labels:
argocd.argoproj.io/secret-type: repository

type: Opaque

stringData:
type: git

url: [git@github.com](mailto:git@github.com):Oluwole-Faluwoye/enterprise-platform-gitops.git

sshPrivateKey: REPLACE_AT_RUNTIME

---

# Runtime Repository Registration

During pipeline execution:

1. Jenkins retrieves the SSH private key from AWS Secrets Manager.
2. Jenkins injects the private key into the repository secret template.
3. Jenkins creates the repository secret.
4. ArgoCD discovers the repository automatically.
5. ArgoCD begins synchronization.

This design prevents private credentials from being stored in Git.

---

# Repository Authentication Flow

GitHub Repository
↓
SSH Deploy Key
↓
AWS Secrets Manager
↓
Jenkins Pipeline
↓
ArgoCD Repository Secret
↓
ArgoCD Repo Server
↓
Application Synchronization

ArgoCD performs repository operations independently of Jenkins.

This separation of responsibilities is a core GitOps principle.

---

# Security Considerations

Recommended practices:

* Use dedicated Deploy Keys
* Use read-only repository permissions
* Separate Jenkins and ArgoCD credentials
* Store secrets outside source control
* Rotate keys periodically
* Audit repository access regularly
* Apply least-privilege IAM permissions

---

# Current Enterprise Enhancements

Implemented:

* Private Repository Authentication Design
* SSH Deploy Key Authentication
* AWS Secrets Manager Integration
* Runtime Secret Injection
* Automated Repository Registration
* ArgoCD Bootstrap Automation

Future Enhancements:

* GitHub App Authentication
* External Secrets Operator
* HashiCorp Vault
* Secret Rotation Automation
* Multi-Cluster ArgoCD
* AWS IRSA Integration

---

# Verification Commands

Verify repository secret:

kubectl get secret enterprise-platform-gitops -n argocd

Verify repository registration:

kubectl get secrets 
-n argocd 
-l argocd.argoproj.io/secret-type=repository

Verify applications:

kubectl get applications -n argocd

Verify root application:

kubectl describe application root-app -n argocd

Verify synchronization:

argocd app get root-app

Expected Result:

NAME       SYNC STATUS   HEALTH STATUS
root-app   Synced        Healthy

Once synchronization succeeds, ArgoCD assumes responsibility for deployment, reconciliation, and drift detection across the Kubernetes platform.
