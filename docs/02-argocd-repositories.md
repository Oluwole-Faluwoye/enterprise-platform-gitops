# ArgoCD Repository Authentication

## Overview

ArgoCD continuously monitors Git repositories and reconciles Kubernetes resources to match the desired state stored in Git.

For this platform, the GitOps repository is treated as the source of truth for all Kubernetes deployments.

Repository:

enterprise-platform-gitops

ArgoCD must be able to independently access this repository.

It is important to understand that Jenkins repository access does not automatically grant repository access to ArgoCD.

These are separate systems with separate authentication requirements.

---

# Repository Access Model

The platform uses SSH-based authentication.

Architecture:

GitHub Repository
↓
ArgoCD Repository Secret
↓
ArgoCD Repo Server
↓
Kubernetes Cluster

ArgoCD periodically pulls repository contents and compares them with the current cluster state.

Any differences are automatically reconciled.

---

# Why SSH Authentication?

Several repository authentication methods exist:

* HTTPS with Personal Access Tokens
* SSH Deploy Keys
* GitHub App Authentication

For this project, SSH authentication was selected because it:

* Mirrors many enterprise GitOps implementations
* Avoids Personal Access Token management
* Provides strong cryptographic authentication
* Allows repository access to be restricted to specific keys
* Demonstrates secure machine-to-machine communication

---

# Public Repository vs Private Repository

The GitOps repository may remain public for portfolio and demonstration purposes.

However, the platform is designed as though the repository were private.

This allows the same architecture to be used later in production environments without major redesign.

The repository authentication workflow remains in place even when the repository is publicly accessible.

This demonstrates enterprise-ready design principles.

---

# Why Secrets Are Not Stored in Git

Private keys must never be committed to source control.

Instead:

* Jenkins stores the SSH private key securely
* The pipeline retrieves the credential at runtime
* Kubernetes secrets are generated dynamically
* ArgoCD consumes the generated secret

Benefits:

* No secret exposure in Git
* Easier credential rotation
* Cleaner audit trail
* Reduced risk of accidental disclosure

---

# Repository Secret Architecture

ArgoCD repository credentials are represented as Kubernetes Secrets.

The secret contains:

* Repository URL
* Repository type
* SSH private key

ArgoCD automatically discovers repository secrets using the label:

argocd.argoproj.io/secret-type: repository

Once detected, the repository becomes available to the ArgoCD Repo Server.

---

# Repository Authentication Flow

GitHub
↓
SSH Key Authentication
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

The following practices are recommended:

* Use dedicated deploy keys
* Use read-only repository permissions
* Avoid sharing Jenkins SSH keys with ArgoCD
* Rotate keys periodically
* Store credentials outside source control
* Audit repository access regularly

---

# Future Enhancements

A mature enterprise implementation would typically replace SSH deploy keys with one of the following:

* GitHub App Authentication
* AWS Secrets Manager
* External Secrets Operator
* Vault Integration

These approaches provide centralized secret management and automated credential rotation.

For learning and portfolio purposes, SSH deploy keys provide an excellent balance between simplicity and enterprise relevance.

---

# Verification Commands

Verify ArgoCD applications:

kubectl get applications -n argocd

Verify application details:

kubectl describe application root-app -n argocd

Verify repository connectivity:

argocd repo list

Verify synchronization state:

argocd app get root-app

Expected result:

NAME       SYNC STATUS   HEALTH STATUS
root-app   Synced        Healthy

Once synchronization succeeds, ArgoCD assumes responsibility for deployment, reconciliation, and drift detection across the Kubernetes platform.
