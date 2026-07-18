# ExternalDNS

## Overview

ExternalDNS is a Kubernetes controller that automatically manages DNS records in supported DNS providers based on Kubernetes resources.

Within the Enterprise Platform, ExternalDNS integrates Kubernetes with Amazon Route53, eliminating the need to manually create or update DNS records whenever applications are deployed.

ExternalDNS continuously watches Kubernetes resources such as Ingresses and Services and reconciles DNS records to match the desired cluster state.

---

# Why ExternalDNS?

Without ExternalDNS, every new application requires manual DNS management.

Typical manual process:

1. Deploy an application.
2. Wait for the AWS Load Balancer to be created.
3. Copy the ALB DNS name.
4. Open the AWS Console.
5. Navigate to Route53.
6. Create an A Record or CNAME.
7. Verify DNS propagation.

This process is slow, repetitive, and prone to human error.

ExternalDNS automates the entire workflow.

---

# Architecture

```
                Kubernetes Ingress
                        │
                        ▼
          AWS Load Balancer Controller
                        │
                        ▼
               AWS Application Load Balancer
                        │
                        ▼
                 ExternalDNS watches
                        │
                        ▼
              Amazon Route53 Hosted Zone
                        │
                        ▼
                  DNS Record Created
                        │
                        ▼
             api.platform.example.com
```

---

# How ExternalDNS Works

ExternalDNS continuously watches Kubernetes resources.

Whenever an Ingress or Service is created, updated, or deleted, ExternalDNS performs the following operations:

1. Reads Kubernetes resources.
2. Determines the desired hostname.
3. Queries Route53.
4. Compares the desired state with the current state.
5. Creates or updates DNS records.
6. Removes obsolete records.

The process is continuous and fully automated.

---

# Supported Kubernetes Resources

ExternalDNS can watch:

- Ingress
- Service
- Gateway API
- Istio Gateway
- CRDs

For this platform, Ingress resources are used.

---

# Route53 Integration

ExternalDNS authenticates with AWS using IAM Roles for Service Accounts (IRSA).

No AWS access keys are stored inside Kubernetes.

Authentication flow:

```
ExternalDNS Pod
        │
        ▼
ServiceAccount
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
Amazon Route53
```

---

# Why IRSA?

Benefits include:

- No static AWS credentials
- Least privilege access
- Automatic credential rotation
- Native EKS integration
- CloudTrail auditing

---

# TXT Ownership Records

ExternalDNS creates TXT records alongside DNS records.

Example:

```
api.platform.example.com

TXT

heritage=external-dns
owner=enterprise-platform
```

These ownership records prevent multiple ExternalDNS instances from modifying the same DNS record.

This mechanism also prevents accidental deletion of records managed by another cluster.

---

# Domain Filters

ExternalDNS only manages approved domains.

Example:

```yaml
domainFilters:
  - platform.example.com
```

This prevents accidental modification of unrelated Route53 Hosted Zones.

---

# Synchronization Policy

The Enterprise Platform uses:

```yaml
policy: sync
```

This means:

- Create missing records.
- Update existing records.
- Remove obsolete records.

The DNS state always reflects the Kubernetes state.

---

# Registry

ExternalDNS uses the TXT registry.

```yaml
registry: txt
```

This is the recommended configuration for Route53.

---

# Platform Integration

ExternalDNS integrates with:

- Amazon EKS
- Route53
- AWS Load Balancer Controller
- Argo CD
- Helm
- IRSA
- Kubernetes Ingress

---

# GitOps Deployment

ExternalDNS is deployed through Argo CD using the upstream Helm chart.

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
ExternalDNS
```

All configuration is version controlled.

---

# Example Workflow

A developer creates an Ingress.

```
Ingress

↓

host: api.platform.example.com
```

AWS Load Balancer Controller creates:

```
ALB
```

ExternalDNS detects:

```
api.platform.example.com
```

ExternalDNS creates:

```
Route53 Record

↓

ALB DNS Name
```

Users can immediately access:

```
https://api.platform.example.com
```

No manual DNS configuration is required.

---

# Security

Security best practices implemented include:

- IAM Roles for Service Accounts
- Least-privilege IAM policies
- Route53 Hosted Zone filtering
- TXT ownership records
- GitOps-managed configuration

---

# Validation

Verify the deployment:

```bash
kubectl get deployment -n kube-system external-dns
```

Verify the pods:

```bash
kubectl get pods -n kube-system
```

Verify the ServiceAccount:

```bash
kubectl get serviceaccount external-dns -n kube-system
```

Verify the ServiceAccount annotation:

```bash
kubectl describe serviceaccount external-dns -n kube-system
```

View controller logs:

```bash
kubectl logs deployment/external-dns -n kube-system
```

Verify Route53 records:

```bash
aws route53 list-resource-record-sets \
--hosted-zone-id <HOSTED_ZONE_ID>
```

---

# Troubleshooting

## DNS Record Not Created

Verify:

- ExternalDNS is running.
- Ingress exists.
- Hostname is configured.
- Hosted Zone exists.
- IAM permissions.
- Route53 Hosted Zone ID.

---

## AccessDenied Errors

Verify:

- IAM Role
- IAM Policy
- IRSA configuration
- ServiceAccount annotation

---

## Record Already Exists

Check:

- TXT ownership record
- Hosted Zone
- Existing DNS records
- ExternalDNS registry configuration

---

## DNS Propagation

Confirm:

- Route53 record exists.
- Domain points to Route53 nameservers.
- DNS cache has expired.
- TTL values are appropriate.

---

# Best Practices

- Use IRSA instead of static AWS credentials.
- Restrict managed domains using `domainFilters`.
- Use the TXT registry for ownership tracking.
- Deploy ExternalDNS through GitOps.
- Monitor controller logs.
- Keep the Helm chart version aligned with the Kubernetes version.
- Avoid manually editing Route53 records that are managed by ExternalDNS.

---

# Enterprise Platform Flow

The networking layer now operates as follows:

```
Developer

        │

        ▼

Git Push

        │

        ▼

Argo CD

        │

        ▼

Ingress

        │

        ▼

AWS Load Balancer Controller

        │

        ▼

Application Load Balancer

        │

        ▼

ExternalDNS

        │

        ▼

Amazon Route53

        │

        ▼

Public DNS

        │

        ▼

Application
```

---

# Summary

ExternalDNS enables fully automated DNS management for the Enterprise Platform by synchronizing Kubernetes resources with Amazon Route53.

Combined with the AWS Load Balancer Controller, GitOps, and IRSA, ExternalDNS removes manual DNS administration, improves deployment consistency, and provides a scalable, production-ready networking solution for applications running on Amazon EKS.

In the next phase of the platform, cert-manager will integrate with this networking layer to automatically provision and renew TLS certificates, enabling secure HTTPS access for all platform services.