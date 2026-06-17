# GitOps Overview

## What Is GitOps?

GitOps is an operational framework that uses Git as the single source of truth for infrastructure, platform services, and application deployments.

Under GitOps, all desired system state is stored in Git repositories.

Changes are introduced through Git commits rather than direct modifications to running environments.

This provides:

* Version control
* Auditability
* Repeatability
* Improved operational consistency

---

# Core GitOps Principle

Desired state exists in Git.

Actual state exists in Kubernetes.

A GitOps controller continuously compares desired state with actual cluster state and reconciles any differences.

Architecture:

Git Repository

↓

Desired State

↓

ArgoCD

↓

Kubernetes Cluster

↓

Actual State

---

# Why GitOps?

Traditional deployment approaches often rely on manual kubectl commands or CI/CD jobs applying manifests directly to clusters.

This creates challenges:

* Configuration drift
* Limited auditability
* Difficult rollbacks
* Inconsistent environments
* Operational risk

GitOps addresses these challenges by making Git the authoritative source of truth.

Benefits include:

* Declarative deployments
* Automated reconciliation
* Improved visibility
* Easier disaster recovery
* Simplified rollback procedures

---

# Git as the Source of Truth

In a GitOps platform, Git defines:

* Kubernetes manifests
* Helm charts
* Application configurations
* Platform services

Manual changes to the cluster are discouraged.

If changes occur outside Git, ArgoCD detects the drift and restores the cluster to the desired state.

---

# Why ArgoCD?

ArgoCD is a Kubernetes-native GitOps controller.

Its primary responsibilities are:

* Repository synchronization
* Continuous reconciliation
* Drift detection
* Automated deployment

ArgoCD continuously monitors Git repositories and compares repository state against cluster state.

---

# Continuous Reconciliation

ArgoCD repeatedly performs the following process:

1. Read desired state from Git.
2. Read actual state from Kubernetes.
3. Compare both states.
4. Detect differences.
5. Apply corrections.

This process runs continuously.

---

# Drift Detection

Drift occurs when the running cluster no longer matches the desired state stored in Git.

Example:

An administrator manually deletes a Deployment.

Without GitOps:

The application remains unavailable until manually restored.

With GitOps:

ArgoCD detects the missing Deployment and recreates it automatically.

Benefits:

* Self-healing environments
* Reduced operational overhead
* Improved reliability

---

# App-of-Apps Pattern

This platform uses ArgoCD's App-of-Apps architecture.

Architecture:

root-app

↓

Application Definitions

↓

Platform Services

↓

Application Workloads

The Root Application acts as the entry point for all managed resources.

Benefits:

* Scalability
* Simplified onboarding
* Centralized management
* Consistent deployment workflows

---

# Repository Structure

enterprise-platform-gitops/

├── applications/

├── platform-services/

├── docs/

└── root-app.yaml

Purpose:

applications/

* ArgoCD Application definitions

platform-services/

* Shared platform resources

docs/

* Platform documentation

root-app.yaml

* Entry point for App-of-Apps architecture

---

# CI/CD vs GitOps

CI/CD and GitOps solve different problems.

CI Responsibilities:

* Build applications
* Execute tests
* Perform security scans
* Create container images
* Push images to ECR

GitOps Responsibilities:

* Deploy applications
* Reconcile cluster state
* Detect drift
* Maintain desired state

---

# Platform Workflow

Developer Commit

↓

Jenkins Pipeline

↓

Terraform Infrastructure Deployment

↓

Amazon EKS

↓

ArgoCD Installation

↓

GitOps Bootstrap

↓

Root Application Registration

↓

Continuous Synchronization

---

# Benefits of GitOps

Operational Benefits:

* Improved consistency
* Automated deployments
* Simplified rollback
* Faster recovery

Security Benefits:

* Full audit trail
* Reduced manual access
* Controlled change management

Business Benefits:

* Increased reliability
* Reduced operational overhead
* Faster delivery cycles

---

# Summary

GitOps transforms Git from a source code repository into the authoritative source of truth for platform operations.

In this platform:

* Jenkins provisions infrastructure
* Terraform creates cloud resources
* ArgoCD manages Kubernetes deployments
* Git defines desired state

This separation of responsibilities creates a scalable, auditable, and enterprise-aligned deployment architecture.
