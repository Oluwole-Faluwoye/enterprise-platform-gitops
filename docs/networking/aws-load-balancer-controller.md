# AWS Load Balancer Controller

## Overview

The AWS Load Balancer Controller is a Kubernetes controller that manages AWS Elastic Load Balancers (Application Load Balancers and Network Load Balancers) for workloads running on Amazon EKS.

Rather than manually creating and configuring load balancers through the AWS Console or Terraform for every application, Kubernetes resources such as Ingresses and Services become the source of truth. The controller observes these resources and automatically provisions, updates, and deletes AWS load balancers as required.

The Enterprise Platform deploys the AWS Load Balancer Controller using Helm and manages it through Argo CD as part of the GitOps workflow.

---

# Why Do We Need It?

Kubernetes itself does not know how to create AWS Application Load Balancers.

Without the controller:

- Ingress resources remain inactive.
- ALBs must be created manually.
- Listener rules must be configured manually.
- Target Groups must be maintained manually.
- Security Groups require manual updates.

The AWS Load Balancer Controller automates all of these tasks.

---

# Responsibilities

The controller is responsible for:

- Creating Application Load Balancers (ALBs)
- Creating Network Load Balancers (NLBs)
- Creating Target Groups
- Registering Kubernetes Pods as targets
- Creating Listener Rules
- Updating ALBs when Ingress resources change
- Deleting unused AWS resources
- Managing Security Group rules

---

# Architecture

```
                    Internet
                        │
                        ▼
                Route53 DNS
                        │
                        ▼
            AWS Load Balancer Controller
                        │
                        ▼
          AWS Application Load Balancer
                        │
                        ▼
               Kubernetes Ingress
                        │
                        ▼
                   Kubernetes Service
                        │
                        ▼
                        Pod
```

---

# GitOps Architecture

The controller is deployed through Argo CD.

```
Git Repository
      │
      ▼
Argo CD
      │
      ▼
Helm Chart
      │
      ▼
AWS Load Balancer Controller
```

This ensures deployments are version controlled, reproducible, and automated.

---

# IAM Authentication

The controller authenticates to AWS using IAM Roles for Service Accounts (IRSA).

No static AWS credentials are stored inside Kubernetes.

Authentication flow:

```
Kubernetes ServiceAccount
            │
            ▼
IAM Role (IRSA)
            │
            ▼
AWS STS
            │
            ▼
Temporary AWS Credentials
            │
            ▼
AWS APIs
```

---

# Why IRSA?

IRSA provides several advantages:

- No long-lived AWS access keys
- Least-privilege permissions
- Automatic credential rotation
- Improved auditability through CloudTrail
- Native integration with Amazon EKS

---

# Service Account Annotation

The controller ServiceAccount includes an annotation referencing the IAM Role.

Example:

```yaml
eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/enterprise-platform-dev-aws-load-balancer-controller
```

This annotation enables Kubernetes to obtain temporary AWS credentials for the controller.

---

# Reconciliation Process

The controller continuously watches Kubernetes resources.

When an Ingress is created:

1. Detect the new Ingress.
2. Create an AWS Application Load Balancer.
3. Create Target Groups.
4. Configure Listeners.
5. Configure Listener Rules.
6. Register Pod IPs.
7. Update AWS Security Groups.
8. Monitor changes continuously.

If the Ingress is modified or deleted, the AWS resources are updated accordingly.

---

# Integration with Other Platform Components

The AWS Load Balancer Controller integrates with:

- Amazon EKS
- AWS IAM (IRSA)
- Argo CD
- ExternalDNS
- cert-manager
- Route53
- Kubernetes Ingress

---

# Security

The controller follows the Principle of Least Privilege.

Only the permissions required to manage load balancers are granted.

Authentication uses:

- IAM Roles for Service Accounts
- AWS STS
- Temporary credentials

No AWS access keys are stored in Kubernetes Secrets.

---

# Validation

Verify the deployment:

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

Verify the pods:

```bash
kubectl get pods -n kube-system
```

Verify the ServiceAccount:

```bash
kubectl get serviceaccount aws-load-balancer-controller -n kube-system
```

Verify the ServiceAccount annotation:

```bash
kubectl describe serviceaccount aws-load-balancer-controller -n kube-system
```

Verify controller logs:

```bash
kubectl logs deployment/aws-load-balancer-controller -n kube-system
```

Verify the IAM Role:

```bash
aws iam get-role --role-name enterprise-platform-dev-aws-load-balancer-controller
```

---

# Troubleshooting

## Controller Pods Not Starting

Check:

- Deployment status
- Pod events
- Controller logs

---

## AccessDenied Errors

Verify:

- IAM Role
- IAM Policy
- ServiceAccount annotation
- IRSA configuration

---

## ALB Not Created

Verify:

- Ingress exists
- Correct IngressClass
- Controller logs
- IAM permissions
- Subnet tagging

---

## Target Registration Issues

Verify:

- Pod readiness
- Service selector
- Health checks
- Security Groups

---

# Best Practices

- Deploy using GitOps.
- Use IRSA instead of static credentials.
- Grant least-privilege IAM permissions.
- Monitor controller logs.
- Keep the controller version aligned with the EKS cluster version.
- Validate IAM permissions before deploying applications.

---

# Summary

The AWS Load Balancer Controller enables Kubernetes to provision and manage AWS load balancers automatically.

By integrating it with Argo CD, Helm, Terraform, and IRSA, the Enterprise Platform achieves a secure, automated, and production-ready ingress architecture that will support application routing, DNS automation, and TLS in subsequent platform sprints.