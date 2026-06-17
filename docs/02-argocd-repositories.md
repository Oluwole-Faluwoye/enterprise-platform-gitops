# ArgoCD Repositories

## Overview

ArgoCD synchronizes Kubernetes resources from Git repositories.

Repositories serve as the source of truth for:

* Kubernetes manifests
* Helm charts
* Kustomize configurations
* Platform services
* Application definitions

Without repositories, ArgoCD has no desired state to synchronize.

---

# Repository Registration

Repositories must be registered with ArgoCD before synchronization can occur.

ArgoCD discovers repositories through Repository Secrets.

Required Information:

* Repository URL
* Repository Type
* Authentication Method

Once registered, repositories become available to the ArgoCD Repo Server.

---

# Supported Repository Types

ArgoCD supports:

* Git Repositories
* Helm Repositories
* OCI Registries

Git repositories are the most common source used in GitOps implementations.

---

# Authentication Methods

ArgoCD supports several repository authentication methods:

* HTTPS with Personal Access Tokens
* SSH Deploy Keys
* GitHub App Authentication

The selected authentication method depends on organizational requirements and security policies.

---

# Public vs Private Repositories

Public repositories:

* No authentication required

Private repositories:

* Authentication required

Enterprise environments typically use private repositories to protect deployment configurations and application definitions.

---

# Repository Secret Architecture

ArgoCD stores repository definitions as Kubernetes Secrets.

Label:

argocd.argoproj.io/secret-type: repository

These secrets are automatically discovered by the ArgoCD Repo Server.

Example:

apiVersion: v1

kind: Secret

metadata:

labels:

```
argocd.argoproj.io/secret-type: repository
```

Once detected, the repository becomes available to ArgoCD.

---

# Repository Synchronization

ArgoCD continuously performs:

Repository State

↓

Comparison

↓

Drift Detection

↓

Reconciliation

↓

Cluster Update

This process ensures Kubernetes resources remain aligned with the desired state stored in Git.

---

# Repository Lifecycle

Typical workflow:

1. Register repository.
2. Create ArgoCD Application.
3. Synchronize repository contents.
4. Deploy resources.
5. Detect drift.
6. Reconcile changes.

Repositories remain continuously monitored after initial deployment.

---

# Verification Commands

List repository secrets:

kubectl get secrets 
-n argocd 
-l argocd.argoproj.io/secret-type=repository

List applications:

kubectl get applications -n argocd

Check synchronization status:

argocd app list

---

# Summary

Repositories form the foundation of GitOps.

ArgoCD continuously synchronizes repository contents with cluster state and ensures Kubernetes resources match the desired configuration stored in Git.
