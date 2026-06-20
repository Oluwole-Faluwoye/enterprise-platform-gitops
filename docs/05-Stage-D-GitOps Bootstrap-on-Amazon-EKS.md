# Stage D – GitOps Bootstrap on Amazon EKS

## Overview

In this stage, we extended our Infrastructure-as-Code (IaC) pipeline beyond Amazon EKS provisioning and introduced GitOps automation using ArgoCD.

Prior to this stage, Jenkins was responsible only for:

* Terraform validation
* Security scanning
* Terraform planning
* Terraform deployment
* EKS cluster creation

After this stage, Jenkins is responsible for:

* Provisioning infrastructure
* Validating EKS readiness
* Installing ArgoCD
* Bootstrapping the GitOps platform
* Handing deployment responsibility to ArgoCD

This creates a clear separation between:

* Infrastructure provisioning
* Platform management
* Application deployment

and aligns with modern enterprise GitOps practices.

---

# Enterprise Architecture

Before Stage D:

Git Push
↓
Jenkins
↓
Terraform
↓
AWS Infrastructure
↓
EKS Cluster

After Stage D:

Git Push
↓
Jenkins
↓
Terraform
↓
AWS Infrastructure
↓
EKS Cluster
↓
ArgoCD Installation
↓
GitOps Bootstrap
↓
ArgoCD Becomes Deployment Engine

---

# Why GitOps?

Traditional Kubernetes deployments often rely on:

kubectl apply

executed manually or from CI pipelines.

This approach introduces:

* Configuration drift
* Lack of auditability
* Difficult rollbacks
* Inconsistent environments

GitOps solves these problems by making Git the source of truth.

Desired state exists in Git.

ArgoCD continuously compares:

Git State
vs
Cluster State

and automatically reconciles differences.

---

# Jenkins Pipeline Flow

The final pipeline now performs the following stages.

## 1. Checkout

Purpose:

Retrieve Infrastructure-as-Code source code from Git.

Command:

checkout scm

---

## 2. Assume Terraform Role

Purpose:

Assume a dedicated IAM role used for Terraform deployments.

Benefits:

* Least privilege access
* Separation of duties
* No long-lived AWS credentials

Command:

aws sts assume-role

---

## 3. Terraform Format

Purpose:

Verify Terraform code follows formatting standards.

Command:

terraform fmt -check -recursive

---

## 4. Create Runtime Variables

Purpose:

Generate terraform.tfvars dynamically using Jenkins parameters.

Variables:

* KEY_NAME
* HOME_IP

This allows deployments to be parameterized without storing values in source control.

---

## 5. Terraform Init

Purpose:

Initialize Terraform backend and providers.

Command:

terraform init

---

## 6. Terraform Validate

Purpose:

Validate Terraform syntax.

Command:

terraform validate

---

## 7. tfsec Security Scan

Purpose:

Detect Terraform security misconfigurations.

Examples:

* Open security groups
* Unencrypted resources
* Excessive IAM permissions

Command:

docker run aquasec/tfsec

---

## 8. Checkov Security Scan

Purpose:

Perform policy-based IaC security scanning.

Examples:

* CIS compliance
* AWS best practices
* Terraform security controls

Command:

docker run bridgecrew/checkov

---

## 9. Terraform Plan

Purpose:

Generate execution plan.

Command:

terraform plan -out=tfplan

Benefits:

* Predictable deployments
* Change review
* Approval workflow

---

## 10. Manual Approval

Purpose:

Prevent accidental infrastructure changes.

Jenkins requires manual approval before applying Terraform.

---

## 11. Terraform Apply

Purpose:

Provision infrastructure.

Resources include:

* VPC
* Subnets
* EKS Cluster
* IAM Roles
* Security Groups
* ECR Repositories

Command:

terraform apply

---

# EKS Validation

After infrastructure creation, Jenkins validates cluster health.

Stage:

Validate EKS Cluster

Purpose:

Ensure cluster exists and is reachable.

Command:

aws eks describe-cluster

Benefits:

* Confirms cluster creation
* Confirms EKS API availability

---

# kubectl Configuration

Stage:

Configure kubectl

Purpose:

Generate kubeconfig automatically.

Command:

aws eks update-kubeconfig

Benefits:

* Jenkins can communicate with Kubernetes
* No manual kubeconfig management

Validation:

kubectl get nodes

This confirms worker nodes joined the cluster.

---

# ArgoCD Installation

Stage:

Install ArgoCD

Purpose:

Deploy ArgoCD using Helm.

Commands:

helm repo add argo
helm repo update

helm upgrade --install argocd

Benefits:

* Repeatable installation
* Idempotent deployments
* Version-controlled deployment method

Why Helm?

Helm provides:

* Package management
* Upgrade capabilities
* Rollback capabilities
* Enterprise standard deployment mechanism

---

# ArgoCD Readiness Validation

Stage:

Wait For ArgoCD

Purpose:

Ensure ArgoCD is fully operational before bootstrapping.

Commands:

kubectl get pods -n argocd

kubectl wait 
--for=condition=available 
deployment/argocd-server

Why?

Without waiting:

Jenkins may attempt GitOps bootstrap before ArgoCD is ready.

This introduces race conditions.

The wait command guarantees readiness.

---

# GitOps Repository Checkout

Stage:

Checkout GitOps Repo

Purpose:

Retrieve GitOps repository.

Repository:

enterprise-platform-gitops

Command:

git clone

via Jenkins Git plugin.

Why Separate Repository?

Infrastructure Repository:

Contains:

* Terraform
* Jenkinsfiles
* Infrastructure code

GitOps Repository:

Contains:

* ArgoCD applications
* Kubernetes manifests
* Helm configurations

This separation is common in mature enterprise environments.

---

# GitOps Bootstrap

Stage:

Bootstrap GitOps

Purpose:

Register Root Application with ArgoCD.

Commands:

kubectl wait 
--for=condition=Established 
crd/applications.argoproj.io

kubectl apply 
-f gitops/root-app.yaml

Why Wait For CRD?

ArgoCD installs Kubernetes Custom Resource Definitions.

Specifically:

applications.argoproj.io

Without waiting:

Jenkins may attempt:

kubectl apply root-app.yaml

before the CRD exists.

Result:

Deployment failure.

The wait command eliminates this race condition.

---

# Root Application

File:

root-app.yaml

Purpose:

Acts as the entry point for GitOps.

Architecture:

root-app
↓
Applications
↓
Platform Services
↓
Future Application Deployments

The Root App enables ArgoCD's App-of-Apps pattern.

Benefits:

* Scalable architecture
* Centralized management
* Easier onboarding

-------------------------------------------------

# ArgoCD Repository Access Configuration

## Overview

During GitOps bootstrap, Jenkins successfully applies the Root Application (`root-app.yaml`) to the Kubernetes cluster. However, ArgoCD must independently access the GitOps repository in order to continuously synchronize Kubernetes resources.

It is important to understand that:

* Jenkins cloning a repository does not grant ArgoCD access.
* ArgoCD maintains its own repository connections.
* ArgoCD must be explicitly configured to authenticate with GitHub.

## Repository URL Standardization

The platform uses SSH-based GitHub authentication.

Repository URL:

git@github.com:Oluwole-Faluwoye/enterprise-platform-gitops.git

This URL is used by:

* Jenkins Git Checkout
* ArgoCD Repository Registration

Using SSH provides several advantages:

* No Personal Access Token expiration concerns
* Improved security posture
* Enterprise-standard Git authentication
* Consistent authentication method across platform components

## Root Application Configuration

The Root Application references the GitOps repository using SSH.

Example:

source:
repoURL: git@github.com:Oluwole-Faluwoye/enterprise-platform-gitops.git
targetRevision: main
path: applications

## Important Consideration

Applying the Root Application does not automatically grant ArgoCD access to GitHub.

The following sequence occurs:

1. Jenkins installs ArgoCD.
2. Jenkins applies root-app.yaml.
3. ArgoCD attempts to clone the GitOps repository.
4. Repository authentication is required.
5. ArgoCD synchronizes desired state from Git.

If repository authentication has not been configured, ArgoCD will report errors similar to:

Repository not accessible

or

Failed to fetch repository

Even though the Root Application was successfully created.

## Required ArgoCD Configuration

ArgoCD must be configured with:

* GitHub SSH private key
* GitHub known hosts entry
* Repository registration

This allows ArgoCD to independently clone and monitor the GitOps repository.

## Verification Commands

Verify ArgoCD applications:

kubectl get applications -n argocd

Verify Root Application details:

kubectl describe application root-app -n argocd

Check ArgoCD repositories:

argocd repo list

Verify synchronization status:

argocd app get root-app

## Expected Successful State

When properly configured:

* ArgoCD successfully connects to GitHub
* Root Application reports Synced status
* Health status reports Healthy
* Platform services and applications are automatically reconciled

Example:

NAME       SYNC STATUS   HEALTH STATUS
root-app   Synced        Healthy

At this point, Git becomes the single source of truth for the Kubernetes platform, and ArgoCD assumes responsibility for ongoing deployment and reconciliation operations.


-----------------------------------------------------------------

# GitOps Verification

Stage:

Verify GitOps

Commands:

kubectl get applications -n argocd

kubectl get pods -n argocd

kubectl get svc -n argocd

Purpose:

Confirm:

* ArgoCD is healthy
* Root application exists
* Services are operational

These commands are intentionally included for troubleshooting and operational visibility.

---

# Troubleshooting Commands

## Check Nodes

kubectl get nodes -o wide

Purpose:

Verify worker nodes are healthy.

---

## Check ArgoCD Pods

kubectl get pods -n argocd

Purpose:

Identify failed pods.

---

## Check ArgoCD Services

kubectl get svc -n argocd

Purpose:

Verify service exposure.

---

## Check ArgoCD Applications

kubectl get applications -n argocd

Purpose:

Verify Root App registration.

---

## Describe Root App

kubectl describe application root-app -n argocd

Purpose:

View synchronization and health status.

---

# Final State

At the end of Stage D:

Jenkins Responsibilities:

✓ Infrastructure Provisioning
✓ EKS Creation
✓ ArgoCD Installation
✓ GitOps Bootstrap

ArgoCD Responsibilities:

✓ Kubernetes Deployments
✓ Drift Detection
✓ Reconciliation
✓ Future Application Delivery

Application pipelines will no longer deploy directly to Kubernetes.

Instead:

Application Pipeline
↓
Build Image
↓
Push To ECR
↓
Update GitOps Repository
↓
Git Commit
↓
ArgoCD Detects Change
↓
Deployment To EKS

This establishes a fully automated GitOps-based Kubernetes platform aligned with enterprise DevOps and Platform Engineering practices.
