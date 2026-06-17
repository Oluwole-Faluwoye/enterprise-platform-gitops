# Application Delivery Architecture

## Overview

The platform follows a GitOps-based application delivery model.

Application source code, deployment configuration, and infrastructure are separated into dedicated repositories.

Repositories:

1. enterprise-platform-infra
2. enterprise-microservices
3. enterprise-platform-gitops

This separation aligns with enterprise platform engineering practices and enables independent ownership of infrastructure, application development, and deployment operations.

---

# Repository Responsibilities

## Infrastructure Repository

Repository:

enterprise-platform-infra

Responsibilities:

- VPC
- EKS
- IAM
- ECR
- Jenkins
- ArgoCD
- Monitoring Infrastructure

Provisioning is performed using Terraform.

---

## Microservices Repository

Repository:

enterprise-microservices

Responsibilities:

- Application Source Code
- Unit Testing
- Docker Image Creation
- Static Analysis
- Security Scanning

The repository does not contain deployment configuration.

Application teams own this repository.

---

## GitOps Repository

Repository:

enterprise-platform-gitops

Responsibilities:

- Helm Charts
- Kubernetes Deployment Configuration
- ArgoCD Applications
- Platform Services
- Environment Configuration

The GitOps repository serves as the source of truth for Kubernetes deployments.

---

# Deployment Flow

Developer Commit

↓

Jenkins Pipeline

↓

Maven Build

↓

Unit Tests

↓

SonarQube Analysis

↓

OWASP Dependency Check

↓

Trivy Security Scan

↓

Docker Build

↓

Amazon ECR Push

↓

Update values-dev.yaml

↓

Git Commit

↓

GitOps Repository

↓

ArgoCD Detection

↓

Kubernetes Deployment

↓

EKS Cluster

---

# Helm Ownership Model

Platform teams own:

- Helm Charts
- Deployment Configuration
- Scaling Policies
- Service Definitions
- Ingress Configuration

Application teams own:

- Source Code
- Business Logic
- Unit Tests
- Docker Images

This separation enables centralized governance and deployment standardization.

---

# Image Versioning

Container images are tagged using Jenkins build numbers.

Example:

auth-service:42

Jenkins automatically updates:

charts/auth-service/values-dev.yaml

ArgoCD detects the Git change and deploys the new image.

---

# GitOps Benefits

Benefits include:

- Deployment auditability
- Version-controlled infrastructure
- Automatic drift correction
- Declarative deployments
- Rollback capability
- Separation of responsibilities
- Enterprise governance