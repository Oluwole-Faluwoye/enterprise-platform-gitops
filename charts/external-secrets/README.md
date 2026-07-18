
Objective

Install the External Secrets Operator using Argo CD and Helm.

Once complete, your platform will look like this:



                           AWS
                            │
                            │
                  Secrets Manager
                            │
                            │
                     IAM IRSA Role
                            │
                            │
                    External Secrets
                     Operator (EKS)
                            │
            ┌───────────────┴───────────────┐
            │                               │
      ClusterSecretStore              ExternalSecret
            │                               │
            └───────────────┬───────────────┘
                            │
                    Kubernetes Secret
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
     Grafana          Alertmanager        Auth Service



We are not writing our own External Secrets Operator chart.

We will install the official Helm chart.

Our chart will only contain:

ClusterSecretStore
ExternalSecrets
Future platform secret resources

This is exactly how most platform teams do it.

Why ClusterSecretStore?

There are two resource types:

SecretStore
Namespace Scoped

Only usable inside one namespace.

ClusterSecretStore
Cluster Scoped

Every namespace can reuse it.

Enterprise platforms almost always use ClusterSecretStore

Why a second Application?

We intentionally separate:

Application 1
External Secrets Operator

Installs:

Controller
CRDs
Webhooks
Application 2
Platform Configuration

Installs:

ClusterSecretStore
ExternalSecrets
Future platform resources

This makes upgrading the operator independent from your configuration.

----------------------------------------------------------------------


Validation (when EKS is recreated)
kubectl get clustersecretstores

Expected:

NAME

aws-secretsmanager

Describe it:

kubectl describe clustersecretstore aws-secretsmanager

You should see:

Ready=True

----------------------------------------------------

Why this matters

Without ClusterSecretStore, every application would need to know:

AWS Region
Authentication method
Secret provider

That leads to duplicated configuration.

Instead:

Applications

↓

ClusterSecretStore

↓

AWS

Every application simply references the shared store.

-------------------------------------------------------

Why creationPolicy: Owner?

This is an important enterprise setting.

It tells the operator:

"I own this Kubernetes Secret."

If the ExternalSecret is deleted:

ExternalSecret deleted

↓

Kubernetes Secret deleted

No orphaned resources remain.

--------------------------------------

Secret Naming Convention

We'll standardize names across the platform.

AWS Secret	         Kubernetes Secret

grafana/admin	     grafana-secret
alertmanager	     alertmanager-secret
auth-service	     auth-service-secret

This makes it obvious where secrets come from and how they're consumed.

---------------------------------------------

Validation (after EKS is recreated)

Check that the ExternalSecret resources exist:

kubectl get externalsecrets -A

Describe one to verify synchronization:

kubectl describe externalsecret grafana-secret

You should see a Ready=True condition once it has synchronized successfully.

Finally, verify that the Kubernetes Secrets have been created:

kubectl get secrets -n monitoring
kubectl get secrets -n default

You should see:

grafana-secret
alertmanager-secret
auth-service-secret

------------------------------------------------

Our Terraform module creates the AWS Secrets Manager resources.

For example:

module "secrets_manager" {

  secrets = {

    "grafana/admin" = {
      description = "Grafana Administrator"
    }

    "alertmanager" = {
      description = "Alertmanager SMTP"
    }

    "auth-service" = {
      description = "Auth Service"
    }

  }

}

This creates the AWS Secrets themselves.

--------------------------------------------------------------

Later you'll populate them

For example:

grafana/admin
{
  "username": "admin",
  "password": "SuperStrongPassword123!"
}
alertmanager
{
  "username": "monitoring@example.com",
  "password": "smtp-password"
}
auth-service
{
  "jwt-secret": "very-long-random-jwt-secret",
  "database-password": "postgres-password"
}
Then the External Secrets Operator does this
AWS Secret

↓

ExternalSecret

↓

Kubernetes Secret

For example:

AWS

grafana/admin

↓

ExternalSecret

↓

grafana-secret

↓

Grafana Deployment
This is actually an enterprise best practice

Many organizations separate responsibilities.

Infrastructure Team

Creates:

Secret
IAM permissions
Policies
Infrastructure
Security Team

Populates:

Production passwords
API Keys
Certificates
Tokens

Terraform never knows the production secret values.

------------------------------------------------------------

For our project

Since you're the Platform Engineer, you can populate them yourself.

When your cluster is recreated, you'll run commands like:

aws secretsmanager put-secret-value \
  --secret-id enterprise-platform/dev/grafana/admin \
  --secret-string '{
    "username":"admin",
    "password":"SuperSecurePassword123!"
  }'

Similarly for Alertmanager:

aws secretsmanager put-secret-value \
  --secret-id enterprise-platform/dev/alertmanager \
  --secret-string '{
    "username":"monitoring@example.com",
    "password":"smtp-password"
  }'

And for the Auth Service:

aws secretsmanager put-secret-value \
  --secret-id enterprise-platform/dev/auth-service \
  --secret-string '{
    "jwt-secret":"very-long-random-secret",
    "database-password":"postgres-password"
  }'

Notice something important.

Earlier we designed our Secrets Manager module like this:

project/environment/secret-name

So the actual AWS secret names will be:

enterprise-platform/dev/grafana/admin

enterprise-platform/dev/alertmanager

enterprise-platform/dev/auth-service

------------------------------------------------------

By Injecting key into the external-secret templates, you have, 

What this gives you

For Development:

project: enterprise-platform

environment: dev

Generates:

enterprise-platform/dev/grafana/admin

enterprise-platform/dev/alertmanager

enterprise-platform/dev/auth-service


-----------------------------------------------
For Staging:


project: enterprise-platform

environment: staging
------------------------------------------------

Automatically becomes:

enterprise-platform/staging/grafana/admin

enterprise-platform/staging/alertmanager

enterprise-platform/staging/auth-service

--------------------------------------------------

Validation Checklist

Once the cluster is recreated, verify the entire flow:

kubectl get applications -n argocd

All applications should be Healthy and Synced.

kubectl get pods -n external-secrets

The External Secrets Operator should be running.

kubectl get clustersecretstores

aws-secretsmanager should exist and report Ready.

kubectl get externalsecrets -A

You should see:

grafana-secret
alertmanager-secret
auth-service-secret
kubectl get secrets -A

You should see the synchronized Kubernetes Secrets in the expected namespaces.

Sprint 7 Completion

Once those resources are deployed and verified, Sprint 7 is complete.

What you accomplished

By the end of Sprint 7, you'll have built:

✅ AWS Secrets Manager as the source of truth
✅ Terraform-managed secret infrastructure
✅ IAM Roles for Service Accounts (IRSA)
✅ External Secrets Operator
✅ Cluster-wide secret store
✅ ExternalSecret resources
✅ Automatic synchronization to Kubernetes
✅ Grafana consuming synchronized secrets
✅ Alertmanager consuming synchronized secrets
✅ Auth Service consuming synchronized secrets
✅ Comprehensive engineering documentation

This is a complete, enterprise-grade secrets management implementation that aligns with modern Kubernetes and AWS platform engineering practices. From here, we can move confidently into Sprint 8, focusing on platform networking, ingress, certificates, or whichever component you've planned next.