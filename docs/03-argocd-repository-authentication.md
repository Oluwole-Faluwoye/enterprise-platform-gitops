# ArgoCD Repository Authentication

## Overview

This document explains how repository authentication is implemented for this platform.

Although the GitOps repository may remain public for portfolio visibility, the platform is intentionally designed as though the repository were private.

This demonstrates enterprise-grade GitOps authentication patterns.

Repository:

enterprise-platform-gitops

---

# Authentication Architecture

GitHub Repository

↓

GitHub Deploy Key

↓

AWS Secrets Manager

↓

Jenkins Pipeline

↓

ArgoCD Repository Secret

↓

ArgoCD Repo Server

↓

Continuous Synchronization

This architecture prevents repository credentials from being stored in Git.

---

# Why Repository Authentication Is Required

The GitOps bootstrap process performs the following steps:

1. Jenkins installs ArgoCD.
2. Jenkins creates the Root Application.
3. ArgoCD attempts to access the GitOps repository.
4. Repository authentication occurs.
5. ArgoCD synchronizes desired state from Git.

Without authentication, ArgoCD cannot access private repositories.

---

# Deploy Key Creation

A dedicated SSH key pair was created specifically for ArgoCD.

Command:

ssh-keygen 
-t ed25519 
-C "argocd-gitops" 
-f argocd-gitops-key

Generated Files:

argocd-gitops-key

argocd-gitops-key.pub

The public key is registered in GitHub as a Deploy Key.

Permission:

Read Only

This follows the principle of least privilege.

---

# AWS Secrets Manager Integration

The private key is stored in AWS Secrets Manager.

Secret Name:

argocd/gitops/private-key

Benefits:

* Centralized secret management
* IAM-based access control
* Audit logging
* Credential rotation capability
* No secrets stored in source control

---

# Jenkins Runtime Secret Retrieval

During pipeline execution, Jenkins retrieves the private key directly from AWS Secrets Manager.

Example:

aws secretsmanager get-secret-value 
--secret-id argocd/gitops/private-key 
--query SecretString 
--output text

The key exists only during pipeline execution.

---

# Dynamic Repository Secret Creation

Jenkins dynamically creates an ArgoCD Repository Secret.

Template:

apiVersion: v1

kind: Secret

metadata:

name: enterprise-platform-gitops

namespace: argocd

labels:

```
argocd.argoproj.io/secret-type: repository
```

type: Opaque

stringData:

type: git

url: [git@github.com](mailto:git@github.com):Oluwole-Faluwoye/enterprise-platform-gitops.git

sshPrivateKey: REPLACE_AT_RUNTIME

The private key is injected at runtime and never committed to Git.

---

# Why Runtime Secret Injection?

Benefits:

* No secrets stored in Git
* No secrets stored in Terraform state
* No secrets stored in Kubernetes manifests
* Simplified credential rotation
* Reduced risk of accidental disclosure

This closely mirrors enterprise GitOps implementations.

---

# Jenkins Authentication vs ArgoCD Authentication

These systems authenticate independently.

Jenkins Authentication:

* Clones repositories during pipeline execution

ArgoCD Authentication:

* Continuously synchronizes repository contents

This separation of responsibilities is a core GitOps principle.

---

# Security Considerations

Recommended practices:

* Use dedicated Deploy Keys
* Use read-only repository permissions
* Store secrets outside source control
* Rotate credentials periodically
* Audit repository access regularly

Private keys must never be:

* Stored in Git repositories
* Embedded in Terraform code
* Printed in Jenkins logs

---

# Verification Commands

Verify repository secret:

kubectl get secret enterprise-platform-gitops -n argocd

Verify applications:

kubectl get applications -n argocd

Verify synchronization:

argocd app get root-app

Expected Result:

NAME       SYNC STATUS   HEALTH STATUS

root-app   Synced        Healthy

---

# Future Enhancements

Potential future improvements:

* GitHub App Authentication
* External Secrets Operator
* HashiCorp Vault
* AWS Secrets Manager CSI Driver
* IAM Roles for Service Accounts (IRSA)

For learning and portfolio purposes, AWS Secrets Manager combined with SSH Deploy Keys provides a secure and enterprise-aligned GitOps authentication workflow.
