# 03 - ArgoCD Repository Authentication

## Overview

This document explains how repository authentication is implemented for the GitOps platform.

Although the GitOps repository may remain public for portfolio visibility, the platform is intentionally designed as though the repository were private.

This demonstrates enterprise-grade GitOps authentication patterns and mirrors how ArgoCD would authenticate in production environments.

Repository:

enterprise-platform-gitops

Before ArgoCD can synchronize applications, it must be able to authenticate and clone the GitOps repository independently.

A common misconception is that because Jenkins can access GitHub, ArgoCD automatically gains access as well.

This is incorrect.

Jenkins and ArgoCD are separate systems with separate authentication requirements.

---

# Authentication Architecture

The platform uses SSH-based GitHub authentication combined with AWS Secrets Manager.

Architecture:

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

This architecture prevents repository credentials from being stored in Git while still allowing ArgoCD to securely authenticate to GitHub.

---

# Why Repository Authentication Is Required

The GitOps bootstrap process performs the following steps:

1. Jenkins installs ArgoCD.
2. Jenkins creates the Root Application.
3. ArgoCD attempts to access the GitOps repository.
4. Repository authentication occurs.
5. ArgoCD synchronizes desired state from Git.

Without authentication:

ArgoCD cannot access the repository.

Typical errors include:

Repository not accessible

Failed to fetch repository

Authentication required

Even though ArgoCD itself is running successfully.

---

# Authentication Methods Evaluated

## Option 1 – HTTPS + Personal Access Token

Authentication Method:

GitHub Personal Access Token (PAT)

Advantages:

* Simple setup
* Easy to understand

Disadvantages:

* Manual token rotation
* Broader permissions
* Personal credentials tied to automation

---

## Option 2 – SSH Deploy Key (Selected)

Authentication Method:

SSH Public / Private Key Pair

Advantages:

* Repository-scoped access
* Read-only permissions
* Enterprise GitOps pattern
* No personal credentials
* Cryptographic authentication

Disadvantages:

* Key management required

This option was selected.

---

## Option 3 – GitHub App Authentication

Advantages:

* Fine-grained permissions
* Centralized administration
* Enterprise-grade scalability

Disadvantages:

* More complex implementation

Future enhancement.

---

# Deploy Key Creation

A dedicated SSH key pair was created specifically for ArgoCD.

## Step 1 – Generate SSH Key Pair

Command:

```bash
ssh-keygen \
-t ed25519 \
-C "argocd-gitops" \
-f argocd-gitops-key
```

Generated Files:

```text
argocd-gitops-key
argocd-gitops-key.pub
```

Private Key:

```text
argocd-gitops-key
```

Public Key:

```text
argocd-gitops-key.pub
```

---

## Step 2 – Register Deploy Key in GitHub

Navigate:

Gitops Repository

↓

Settings

↓

Deploy Keys

↓

Add Deploy Key

Title : argocd-gitops

Display Public Key:

```bash
cat argocd-gitops-key.pub

```

Paste into GitHub.

"DO NOT" Allow write access

Because this is majorly for Argocd and it only needs to read the gitops repository and doesn't need to write in the repo.   

( It is the other github ssh that needs write access cos it will be commiting and updating repos)


---

# Why Secrets Are Not Stored in Git

Private keys must never be committed to source control.

The following approaches are prohibited:

❌ Git Repository

❌ Terraform Variables

❌ Helm Values

❌ Jenkinsfile

❌ Plain Text Documentation

Instead:

AWS Secrets Manager stores the private key.

Benefits:

* Centralized secret management
* IAM-controlled access
* Audit logging
* Secret rotation support
* No secrets stored in source control

---

# AWS Secrets Manager Integration

The private key is stored in AWS Secrets Manager.

Store the private key with the following commands:

```bash
aws secretsmanager create-secret \
--name argocd/gitops/private-key \
--secret-string file://argocd-gitops-key
```

Verification:

```bash
aws secretsmanager get-secret-value \
--secret-id argocd/gitops/private-key
```

Expected Result:

OpenSSH private key content is returned.

---

# Jenkins Runtime Secret Retrieval

During pipeline execution, Jenkins retrieves the private key directly from AWS Secrets Manager.

Example:

```bash
PRIVATE_KEY=$(aws secretsmanager get-secret-value \
  --secret-id argocd/gitops/private-key \
  --query SecretString \
  --output text)
```

The key exists only during pipeline execution.

It is never stored in Git.

---

# Dynamic Repository Secret Creation

Jenkins dynamically creates an ArgoCD Repository Secret.

Example:

```yaml
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
  url: git@github.com:Oluwole-Faluwoye/enterprise-platform-gitops.git

  sshPrivateKey: |
    <runtime injected key>
```

The secret is generated during pipeline execution and applied directly to the Kubernetes cluster.

The private key is never committed to Git.

---

# Initial Implementation Failure

Original approach:

```bash
sed
```

was used to inject the SSH key into the manifest.

Pipeline Error:

```text
sed: unterminated s command
```

Root Cause:

SSH private keys are multiline values.

The sed replacement broke when processing multiline content.

---

# Second Implementation Failure

Alternative approach:

```bash
python3
```

Pipeline Error:

```text
python3: not found
```

Root Cause:

The Jenkins execution environment did not contain Python.

---

# Final Solution

Repository Secret generated dynamically using a here-document.

Implementation:

```bash
cat > repository-secret.yaml <<EOF
...
EOF
```

Private key appended:

```bash
echo "$PRIVATE_KEY" | sed 's/^/    /'
```

Result:

A valid Kubernetes Secret is generated during every pipeline execution.

---

# Applying Repository Authentication

Apply Secret:

```bash
kubectl apply -f repository-secret.yaml
```

Verify:

```bash
kubectl get secret enterprise-platform-gitops \
-n argocd
```

Expected Result:

```text
enterprise-platform-gitops
```

exists in the argocd namespace.

---

# Jenkins Authentication vs ArgoCD Authentication

These systems authenticate independently.

## Jenkins Authentication

Purpose:

Clone repositories during CI/CD execution.

Credential:

github-ssh

Used For:

* Infrastructure Repository
* Microservices Repository
* GitOps Repository Updates

---

## ArgoCD Authentication

Purpose:

Continuously synchronize repository contents.

Authentication Method:

GitHub Deploy Key

Stored In:

AWS Secrets Manager

Injected By:

Jenkins Pipeline

Consumed By:

ArgoCD Repository Secret

Used For:

* Root Application
* Child Applications
* Continuous Reconciliation

---

# Authentication Flow

GitHub Repository

↓

Deploy Key

↓

AWS Secrets Manager

↓

Jenkins Pipeline

↓

Repository Secret

↓

ArgoCD Repo Server

↓

Continuous Synchronization

ArgoCD performs repository operations independently of Jenkins.

This separation of responsibilities is a core GitOps principle.

---

# Security Considerations

Recommended Practices:

* Use dedicated Deploy Keys
* Use read-only repository permissions
* Store secrets outside Git
* Rotate credentials periodically
* Audit repository access regularly
* Separate Jenkins and ArgoCD credentials
* Avoid exposing secrets in logs

Private keys must never be:

* Stored in Git repositories
* Embedded in Terraform code
* Printed in Jenkins logs
* Shared between systems unnecessarily

---

# Verification Commands

Verify Secret:

```bash
kubectl get secret enterprise-platform-gitops \
-n argocd
```

Verify Applications:

```bash
kubectl get applications -n argocd
```

Verify Root Application:

```bash
kubectl describe application root-app \
-n argocd
```

Verify Synchronization:

```bash
argocd app get root-app
```

Expected:

```text
NAME       SYNC STATUS   HEALTH STATUS
root-app   Synced        Healthy
```

---

# Lessons Learned

Authentication between Jenkins and GitHub does not automatically grant authentication between ArgoCD and GitHub.

GitOps platforms should authenticate independently using dedicated credentials.

Secrets should never be stored in source control.

AWS Secrets Manager combined with runtime secret injection provides a secure, enterprise-aligned solution.

SSH Deploy Keys provide a simple, secure, and production-relevant mechanism for repository authentication while maintaining GitOps principles and separation of responsibilities.

---

# Future Enhancements

Potential future improvements:

* GitHub App Authentication
* External Secrets Operator
* HashiCorp Vault
* AWS Secrets Manager CSI Driver
* IAM Roles for Service Accounts (IRSA)

For learning and portfolio purposes, AWS Secrets Manager combined with SSH Deploy Keys provides an excellent balance between simplicity, security, and enterprise relevance.
