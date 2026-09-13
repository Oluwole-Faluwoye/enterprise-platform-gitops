# Application Golden Path

## Enterprise Platform

**Status:** Implemented  
**Version:** 1.0  
**Environment:** Development  
**Primary Platform:** AWS EKS  
**Deployment Model:** Helm + ArgoCD + GitOps  
**Secrets Management:** AWS Secrets Manager + External Secrets Operator  
**Observability:** Prometheus + Loki + Grafana + Alertmanager  
**Application Template:** `charts/service-template`

---

# 1. Purpose

The Application Golden Path provides a standardized and repeatable way for developers to deploy an application onto the Enterprise Platform.

The objective is to make the secure and operationally correct path the easiest path for developers.

A developer should not have to independently design and implement:

- Kubernetes Deployments
- Kubernetes Services
- ServiceAccounts
- Horizontal Pod Autoscaling
- Health probes
- Resource requests and limits
- Ingress
- Application monitoring
- Metrics collection
- Secrets integration
- AWS Secrets Manager integration
- Kubernetes secret references
- Naming conventions
- Environment configuration
- GitOps deployment configuration

Instead, the platform provides a reusable Helm chart called:

```text
service-template

The developer primarily supplies application-specific configuration through Helm values.

2. Golden Path Philosophy

The Application Golden Path follows several platform engineering principles.

2.1 Standardization

Every application should follow a common deployment model.

Instead of every team creating Kubernetes manifests differently:

Developer A
    └── custom Kubernetes YAML

Developer B
    └── different Kubernetes YAML

Developer C
    └── completely different deployment model

the platform provides:

                    service-template
                          │
          ┌───────────────┼────────────────┐
          │               │                │
       App A            App B            App C
          │               │                │
       values            values           values

The platform owns the deployment patterns.

The application team owns application-specific configuration.

3. High-Level Architecture

The Application Golden Path fits into the wider Enterprise Platform architecture.

Developer
    │
    ▼
Application Source Repository
    │
    ▼
Jenkins CI
    │
    ├── Build
    ├── Unit Tests
    ├── SonarQube
    ├── Security Scanning
    └── Docker Build
    │
    ▼
Amazon ECR
    │
    ▼
GitOps Repository
    │
    ▼
ArgoCD
    │
    ▼
Helm
    │
    ▼
Application Golden Path
    │
    ├── Deployment
    ├── Service
    ├── ServiceAccount
    ├── HPA
    ├── Ingress
    ├── ServiceMonitor
    └── ExternalSecret
    │
    ▼
Amazon EKS
    │
    ├── Application Pods
    │
    ├── Prometheus
    ├── Loki
    ├── Grafana
    └── Alertmanager
    │
    ▼
AWS Platform Services
    │
    ├── ECR
    ├── Secrets Manager
    ├── RDS
    ├── IAM
    └── VPC

The broader platform architecture also defines Prometheus for metrics, Loki for logs, OpenTelemetry for traces, Grafana for visualization, and Alertmanager for alert delivery.

4. Repository Structure

The Application Golden Path is implemented primarily in the GitOps repository.

Example:

enterprise-platform-gitops/
│
├── applications/
│
│   ├── auth-service.yaml
│   ├── external-secrets.yaml
│   └── external-secrets-platform.yaml
│
├── charts/
│
│   ├── service-template/
│   │
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   │
│   │   ├── values/
│   │   │   └── payment-service-dev.yaml
│   │   │
│   │   ├── templates/
│   │   │   ├── _helpers.tpl
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── serviceaccount.yaml
│   │   │   ├── hpa.yaml
│   │   │   ├── ingress.yaml
│   │   │   ├── servicemonitor.yaml
│   │   │   └── externalsecret.yaml
│   │   │
│   │   └── docs/
│   │       └── application-golden-path.md
│   │
│   ├── external-secrets/
│   │
│   └── monitoring-assets/
│
└── scripts/
    └── secrets/
        └── create-payment-service-secret.sh
5. Helm Chart

The core of the Golden Path is:

charts/service-template

The chart contains reusable Kubernetes templates.

The application does not need to duplicate those templates.

The application supplies values.

6. Chart.yaml

The chart metadata is defined in:

charts/service-template/Chart.yaml

Example:

apiVersion: v2

name: service-template

description: Standard Enterprise Platform service template

type: application

version: 1.0.0

appVersion: "1.0.0"

The important distinction is:

version

represents the Helm chart version.

While:

appVersion

represents the application version represented by the chart.

7. values.yaml

The main values.yaml defines the configuration contract for applications.

It establishes the options that developers can configure without modifying the underlying templates.

Conceptually:

values.yaml
    │
    ├── application
    ├── image
    ├── service
    ├── replicaCount
    ├── resources
    ├── health
    ├── autoscaling
    ├── ingress
    ├── serviceAccount
    ├── secrets
    └── observability

The developer should normally modify values rather than Kubernetes templates.

This creates a clean separation:

Platform Team
    │
    └── owns templates

Application Team
    │
    └── owns values
8. Environment-Specific Values

Applications can have environment-specific values.

Example:

charts/service-template/values/payment-service-dev.yaml

Example:

global:
  project: enterprise-platform
  environment: dev

service:
  name: payment-service

image:
  repository: example/payment-service
  tag: "1.0.0"

This allows the same Golden Path to support:

dev
staging
production

without duplicating the underlying Helm templates.

9. Application Configuration Example

A complete application configuration can look like:

global:
  project: enterprise-platform
  environment: dev

service:
  name: payment-service

image:
  repository: example/payment-service
  tag: "1.0.0"

secrets:
  enabled: true

  external:
    enabled: true
    refreshInterval: 1h

    secretStore:
      name: aws-secretsmanager

    data:
      - secretKey: database-username
        property: database-username

      - secretKey: database-password
        property: database-password

      - secretKey: jwt-secret
        property: jwt-secret

env:
  - name: SPRING_DATASOURCE_USERNAME
    secretKey: database-username

  - name: SPRING_DATASOURCE_PASSWORD
    secretKey: database-password

  - name: JWT_SECRET
    secretKey: jwt-secret

This configuration is intentionally declarative.

The developer says:

"My application needs these three secret values."

The platform determines how those values are retrieved and injected.

10. Deployment

The Golden Path generates a Kubernetes Deployment.

The Deployment is responsible for:

running application containers
maintaining the desired replica count
rolling updates
connecting environment variables
health probes
resources
ServiceAccount
volumes
scheduling configuration

The application image is configured through:

image:
  repository: example/payment-service
  tag: "1.0.0"

The resulting Kubernetes container uses:

example/payment-service:1.0.0
11. Service

The Golden Path creates a Kubernetes Service.

The Service provides a stable network endpoint for application Pods.

Conceptually:

                 payment-service
                       │
              Kubernetes Service
                       │
            ┌──────────┴──────────┐
            │                     │
            ▼                     ▼
        Pod #1                 Pod #2

Pods are temporary.

The Service provides stable networking even when Pods are replaced.

12. ServiceAccount

Each application runs using a Kubernetes ServiceAccount.

The Deployment references the ServiceAccount:

serviceAccountName:

The ServiceAccount is important for application identity.

It also provides the foundation for future AWS workload identity patterns.

Applications should not receive broad AWS permissions.

AWS permissions should be granted according to workload requirements and least privilege.

13. Health Probes

The Golden Path supports Kubernetes health probes.

Two important probes are:

Liveness
Readiness
Liveness

Answers:

Is the application still functioning?

If the application becomes unhealthy, Kubernetes can restart the container.

Readiness

Answers:

Is the application ready to receive traffic?

If the application is not ready, Kubernetes removes it from normal traffic routing.

14. Resource Requests and Limits

Applications should define resource requests and limits.

Example:

resources:
  requests:
    cpu: 250m
    memory: 256Mi

  limits:
    cpu: 500m
    memory: 512Mi

Requests influence scheduling.

Limits constrain resource consumption.

This prevents a single application from consuming unlimited node resources.

15. Horizontal Pod Autoscaling

The Golden Path supports Horizontal Pod Autoscaling.

Example:

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80

This means:

Minimum:
2 Pods

Maximum:
5 Pods

Target:
80% CPU utilization

Conceptually:

             Application Load
                    │
                    ▼
              CPU increases
                    │
                    ▼
                   HPA
                    │
       ┌────────────┼────────────┐
       ▼            ▼            ▼
     2 Pods       3 Pods       5 Pods
16. Ingress

Ingress is optional.

An application can remain internal:

Internet
   X
   │
   └── ClusterIP Service

or expose HTTP/HTTPS traffic:

Internet
   │
   ▼
Ingress / ALB
   │
   ▼
Kubernetes Service
   │
   ▼
Application Pods

The important Golden Path principle is that external exposure is a deliberate configuration choice.

Applications should not automatically become internet-facing.

17. Secrets Management

Secrets are intentionally separated from Git.

This is one of the most important security decisions in the Golden Path.

The Git repository contains:

secret names
secret mappings
references
configuration

It does not contain:

actual passwords
JWT secrets
database credentials
API keys
18. AWS Secrets Manager

Actual secret values are stored in AWS Secrets Manager.

For example:

enterprise-platform/dev/payment-service

This is an AWS Secrets Manager secret.

It is not an S3 bucket.

It is also not a file container.

AWS Secrets Manager stores a secret value associated with a secret name.

In our design, the secret value is a JSON object.

Conceptually:

{
  "database-username": "admin",
  "database-password": "********",
  "jwt-secret": "********"
}

Therefore:

enterprise-platform/dev/payment-service

is the name/identifier of the secret.

Inside that secret are multiple properties.

19. Secret Naming Convention

The Golden Path constructs the AWS secret name from:

project
+
environment
+
application

For example:

enterprise-platform
        +
       dev
        +
payment-service

becomes:

enterprise-platform/dev/payment-service

This gives us a predictable naming convention.

Examples:

enterprise-platform/dev/auth-service

enterprise-platform/dev/payment-service

enterprise-platform/dev/user-service

enterprise-platform/staging/payment-service

enterprise-platform/prod/payment-service

19.1 Dynamic Secret Naming — Single Service Identity

The Application Golden Path uses the application service name as the single source of identity for secret naming.

The developer should not manually provide the Kubernetes Secret name or the AWS Secrets Manager secret name.

The developer provides:

service:
  name: payment-service

The platform derives the Kubernetes Secret name:

payment-service-secret

and the AWS Secrets Manager path:

enterprise-platform/dev/payment-service

The naming relationship is:

service.name
     │
     ├── Kubernetes Secret
     │      └── payment-service-secret
     │
     └── AWS Secrets Manager
            └── enterprise-platform/dev/payment-service

This creates a single naming contract across the platform.

19.2 Why Developers Should Not Provide Secret Names

The previous implementation required developers to specify values such as:

secrets:
  kubernetesSecret: payment-service-secret

  external:
    awsSecret: payment-service

This creates unnecessary duplication.

A developer could accidentally configure:

service:
  name: payment-service

secrets:
  kubernetesSecret: payments-secret

  external:
    awsSecret: payments-prod

The application identity and secret identity could then become inconsistent.

The Golden Path eliminates this possibility by deriving the names automatically.

The developer declares:

service:
  name: payment-service

The platform determines the rest.

19.3 Kubernetes Secret Name Helper

The Kubernetes Secret name is generated centrally through the Helm helper:

{{/*
Create the Kubernetes Secret name for the service.
*/}}
{{- define "service-template.secretName" -}}
{{- printf "%s-secret" (include "service-template.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

For:

service:
  name: payment-service

the helper produces:

payment-service-secret

The Deployment uses the same helper:

secretKeyRef:
  name: {{ include "service-template.secretName" . }}
  key: {{ .secretKey }}

The ExternalSecret uses the same helper:

target:
  name: {{ include "service-template.secretName" . }}
  creationPolicy: Owner

This is important because both resources derive the name from the exact same function.

Therefore:

Deployment
     │
     │ references
     ▼
payment-service-secret
     ▲
     │ created by
     │
ExternalSecret

There is no manually duplicated secret name.

19.4 AWS Secret Path Helper

The AWS Secrets Manager path is also generated from the service identity.

The helper is:

{{/*
Create the AWS Secrets Manager path for the service.
*/}}
{{- define "service-template.awsSecretPath" -}}
{{- printf "%s/%s/%s" .Values.global.project .Values.global.environment (include "service-template.fullname" .) }}
{{- end }}

Given:

global:
  project: enterprise-platform
  environment: dev

service:
  name: payment-service

Helm generates:

enterprise-platform/dev/payment-service

The ExternalSecret therefore uses:

remoteRef:
  key: {{ include "service-template.awsSecretPath" $ }}
  property: {{ .property }}

instead of requiring the developer to specify:

awsSecret: payment-service
19.5 Final Developer Secret Configuration

The developer-facing configuration should therefore look like:

global:
  project: enterprise-platform
  environment: dev

service:
  name: payment-service

image:
  repository: example/payment-service
  tag: "1.0.0"

secrets:
  enabled: true

  external:
    enabled: true
    refreshInterval: 1h

    secretStore:
      name: aws-secretsmanager

    data:
      - secretKey: database-username
        property: database-username

      - secretKey: database-password
        property: database-password

      - secretKey: jwt-secret
        property: jwt-secret

Notice that there is no:

kubernetesSecret:

and there is no:

awsSecret:

The platform derives both.

19.6 Fail-Fast Service Identity Validation

Because secret names depend on the service identity, the template validates that a service name exists.

The ExternalSecret template should contain:

{{- if not .Values.service.name }}
{{- fail "service.name is required when external secrets are enabled" }}
{{- end }}

Therefore:

service:
  name: payment-service

is valid.

But:

service:
  name: ""

causes Helm rendering to fail.

This ensures the platform never attempts to construct an incomplete secret path or Kubernetes Secret name.

19.7 Final Secret Naming Contract

The Golden Path therefore establishes the following deterministic contract:

Input	Derived Resource
service.name	Kubernetes application identity
service.name	Kubernetes Secret name
global.project + global.environment + service.name	AWS Secrets Manager path

For example:

service.name
    │
    ▼
payment-service
    │
    ├───────────────► payment-service-secret
    │                 Kubernetes Secret
    │
    └───────────────► enterprise-platform/dev/payment-service
                      AWS Secrets Manager

This is a key platform-engineering improvement because one developer-provided identifier drives the resource relationships.

19.8 Validation Performed

The implementation was validated using:

helm lint charts/service-template

Result:

1 chart(s) linted, 0 chart(s) failed

The rendered chart was then inspected with:

helm template payment-service charts/service-template \
  -f charts/service-template/values/payment-service-dev.yaml \
  > /tmp/payment-secret-final.yaml

The rendered ExternalSecret produced:

target:
  name: payment-service-secret
  creationPolicy: Owner

and the remote AWS secret references resolved to:

enterprise-platform/dev/payment-service

The final rendered relationship is therefore:

service.name
     │
     ▼
payment-service
     │
     ├── ExternalSecret
     │       └── payment-service
     │
     ├── Kubernetes Secret
     │       └── payment-service-secret
     │
     └── AWS Secrets Manager
             └── enterprise-platform/dev/payment-service


20. Secret Properties

A single AWS Secrets Manager secret can contain multiple properties.

For example:

{
  "database-username": "admin",
  "database-password": "super-secret-password",
  "jwt-secret": "long-random-secret"
}

This means we do NOT create:

S3 bucket
    ├── database-username.txt
    ├── database-password.txt
    └── jwt-secret.txt

That is not how this Golden Path works.

Instead:

AWS Secrets Manager
        │
        ▼
enterprise-platform/dev/payment-service
        │
        ├── database-username
        ├── database-password
        └── jwt-secret
21. Creating Secrets

Actual secret values should be created outside Git.

The repository contains a helper script:

scripts/secrets/create-payment-service-secret.sh

The script uses AWS CLI to create or update the secret in AWS Secrets Manager.

The secret values are entered locally.

They are never committed to Git.

The AWS CLI authenticates using the user's AWS identity.

For example:

aws sts get-caller-identity

should be used to verify the AWS identity before creating secrets.

22. External Secrets Operator

The Kubernetes cluster does not directly store the source of truth for the application's credentials.

Instead, External Secrets Operator retrieves the values from AWS Secrets Manager.

The architecture is:

AWS Secrets Manager
        │
        │
        ▼
External Secrets Operator
        │
        ▼
Kubernetes Secret
        │
        ▼
Application Pod
23. ClusterSecretStore

The platform provides a shared:

ClusterSecretStore

called:

aws-secretsmanager

The ClusterSecretStore defines how Kubernetes connects to AWS Secrets Manager.

The application does not need to know:

AWS region
AWS authentication implementation
Secrets Manager service configuration

The application simply references:

secretStoreRef:
  name: aws-secretsmanager
  kind: ClusterSecretStore

This keeps provider configuration centralized.

24. ExternalSecret

The application declares which properties it needs.

Example:

data:
  - secretKey: database-username
    remoteRef:
      key: enterprise-platform/dev/payment-service
      property: database-username

  - secretKey: database-password
    remoteRef:
      key: enterprise-platform/dev/payment-service
      property: database-password

  - secretKey: jwt-secret
    remoteRef:
      key: enterprise-platform/dev/payment-service
      property: jwt-secret

This means:

AWS property
      │
      ▼
database-username
      │
      ▼
Kubernetes key
      │
      ▼
database-username

The same happens for the password and JWT secret.

25. Kubernetes Secret

External Secrets Operator creates:

payment-service-secret

inside the application's Kubernetes namespace.

Conceptually:

payment-service-secret

data:
  database-username: ...
  database-password: ...
  jwt-secret: ...

This Kubernetes Secret is generated from AWS Secrets Manager.

The AWS secret remains the source of truth.

26. Creation Policy

The ExternalSecret uses:

creationPolicy: Owner

This means the ExternalSecret owns the generated Kubernetes Secret.

The relationship is:

ExternalSecret
      │
      │ owns
      ▼
Kubernetes Secret

If the ExternalSecret is deleted, the generated Kubernetes Secret can also be removed according to the ownership behavior.

This reduces orphaned resources.

27. Application Secret Consumption

The Deployment consumes the generated Kubernetes Secret using:

valueFrom:
  secretKeyRef:

For example:

- name: SPRING_DATASOURCE_USERNAME
  valueFrom:
    secretKeyRef:
      name: payment-service-secret
      key: database-username

The application receives:

SPRING_DATASOURCE_USERNAME

without the secret value appearing in the Deployment manifest.

Similarly:

- name: SPRING_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: payment-service-secret
      key: database-password

and:

- name: JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: payment-service-secret
      key: jwt-secret
28. Complete Secret Flow

The complete flow is:

Developer
   │
   │ creates secret locally
   ▼
AWS Secrets Manager
   │
   │ enterprise-platform/dev/payment-service
   │
   ├── database-username
   ├── database-password
   └── jwt-secret
   │
   ▼
ClusterSecretStore
   │
   ▼
ExternalSecret
   │
   ▼
payment-service-secret
   │
   ├── database-username
   ├── database-password
   └── jwt-secret
   │
   ▼
Deployment
   │
   ├── SPRING_DATASOURCE_USERNAME
   ├── SPRING_DATASOURCE_PASSWORD
   └── JWT_SECRET
   │
   ▼
Application

At no point should the actual secret values be committed to Git.

29. Fail-Fast Validation

The Golden Path intentionally validates configuration before deployment.

For example, External Secrets requires:

service.name
secrets.external.data

If these values are missing, Helm fails.

Example validation:

{{- if not .Values.secrets.external.awsSecret }}
{{- fail "secrets.external.awsSecret is required when external secrets are enabled" }}
{{- end }}

This is preferable to allowing invalid configuration to reach the cluster.

30. Example of Invalid Configuration

If:

awsSecret: ""

is supplied while External Secrets is enabled, Helm should fail:

Error:
secrets.external.awsSecret is required when external secrets are enabled

This was intentionally tested.

The Golden Path therefore catches the problem during rendering instead of waiting for Kubernetes or the application to fail.

31. Application Environment Variables

The application can consume secrets through environment variables.

Example:

env:
  - name: SPRING_DATASOURCE_USERNAME
    secretKey: database-username

  - name: SPRING_DATASOURCE_PASSWORD
    secretKey: database-password

  - name: JWT_SECRET
    secretKey: jwt-secret

The Deployment template converts these into Kubernetes secretKeyRef references.

The developer does not need to manually write the Kubernetes syntax.

32. Metrics and Prometheus

The Application Golden Path is designed to integrate applications with Prometheus.

The application exposes metrics through an endpoint such as:

/actuator/prometheus

The ServiceMonitor identifies the application as a Prometheus scrape target.

Conceptually:

Application
    │
    ▼
/actuator/prometheus
    │
    ▼
ServiceMonitor
    │
    ▼
Prometheus

This means developers do not need to manually modify the central Prometheus configuration for every application.

33. Logs and Loki

Application logs should be written to standard output/error.

Conceptually:

Application
    │
    ▼
stdout / stderr
    │
    ▼
Kubernetes
    │
    ▼
Log collector
    │
    ▼
Loki
    │
    ▼
Grafana

Loki is a platform-level capability.

The application Golden Path only needs to ensure that applications follow the platform logging contract.

34. Grafana

Grafana provides the visualization layer.

The intended observability model is:

                  Grafana
                 /   |   \
                /    |    \
               ▼     ▼     ▼
         Prometheus Loki  Traces
             │       │
             │       │
          Metrics   Logs

Applications should therefore be observable without every development team creating its own monitoring stack.

35. Alertmanager

Prometheus can evaluate alert rules.

When an alert fires:

Application / Platform
        │
        ▼
    Prometheus
        │
        ▼
   Alert Rule
        │
        ▼
   Alertmanager
        │
        ▼
 Notification

The platform monitoring layer owns the alerting infrastructure.

The application may contribute application-specific alert rules.

36. Observability Contract

The Application Golden Path should eventually provide a consistent observability contract.

Every application should ideally provide:

Health
  ├── liveness
  └── readiness

Metrics
  └── /actuator/prometheus

Logs
  └── stdout/stderr

Tracing
  └── OpenTelemetry

The platform provides the collection and visualization infrastructure.

37. GitOps

The Application Golden Path is designed for GitOps.

ArgoCD watches the GitOps repository.

Conceptually:

Git
 │
 │ change
 ▼
ArgoCD
 │
 │ render Helm
 ▼
Kubernetes

ArgoCD can automatically:

sync
prune
self-heal

and create application namespaces where configured.

38. Example ArgoCD Application

An application can be represented by an ArgoCD Application.

Conceptually:

apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: auth-service
  namespace: argocd

spec:
  source:
    repoURL: git@github.com:Oluwole-Faluwoye/enterprise-platform-gitops.git
    targetRevision: main
    path: charts/auth-service

    helm:
      valueFiles:
        - values-dev.yaml

  destination:
    server: https://kubernetes.default.svc
    namespace: auth

  syncPolicy:
    automated:
      prune: true
      selfHeal: true

    syncOptions:
      - CreateNamespace=true

The existing auth-service ArgoCD configuration follows this model.

39. Jenkins and GitOps

Jenkins is responsible for application CI.

The general flow is:

Developer
    │
    ▼
GitHub
    │
    ▼
Jenkins
    │
    ├── Build
    ├── Test
    ├── SonarQube
    ├── Security Scan
    └── Docker Build
    │
    ▼
Amazon ECR
    │
    ▼
GitOps Repository
    │
    ▼
ArgoCD

The separation is intentional.

Jenkins answers:

"Can we build and validate this application?"

ArgoCD answers:

"What should be running in Kubernetes?"

40. Separation of Responsibilities

The Golden Path follows this ownership model.

Developer

Owns:

application code
application configuration
Dockerfile where appropriate
application-specific Helm values
application metrics
application health endpoints
Platform Team

Owns:

service-template
Kubernetes deployment patterns
HPA implementation
Service implementation
ServiceAccount patterns
observability integration
secrets integration
security defaults
platform tooling
Security / Cloud Platform

Owns:

AWS IAM
Secrets Manager
KMS
networking
security policies
cluster-level security
GitOps

Owns:

desired deployment state
environment configuration
ArgoCD applications
deployment history
41. Developer Experience

The goal is that a developer should eventually be able to onboard a new service by supplying something similar to:

global:
  project: enterprise-platform
  environment: dev

service:
  name: payment-service

image:
  repository: 761018849945.dkr.ecr.us-east-1.amazonaws.com/payment-service
  tag: "1"

secrets:
  enabled: true

  kubernetesSecret: payment-service-secret

  external:
    enabled: true

    awsSecret: payment-service

    data:
      - secretKey: database-username
        property: database-username

      - secretKey: database-password
        property: database-password

      - secretKey: jwt-secret
        property: jwt-secret

The platform generates the Kubernetes resources.

42. What the Developer Does NOT Need to Write

The developer should not need to manually create:

Deployment YAML
Service YAML
HPA YAML
ServiceAccount YAML
ServiceMonitor YAML
ExternalSecret YAML
Secret YAML

The Golden Path generates those resources.

This is the fundamental purpose of the template.

43. Validation Workflow

Before deploying an application, validate the Helm chart.

Helm lint
helm lint charts/service-template

Expected:

1 chart(s) linted, 0 chart(s) failed
44. Render the Chart

Render the application without deploying it:

helm template payment-service charts/service-template \
  -f charts/service-template/values/payment-service-dev.yaml \
  > /tmp/payment-secret-auto.yaml

This allows the rendered Kubernetes resources to be inspected.

45. Inspect ExternalSecret

Use:

grep -n -A15 -B5 "kind: ExternalSecret" \
  /tmp/payment-secret-auto.yaml

Confirm:

ExternalSecret
    │
    ├── payment-service-secret
    │
    ├── aws-secretsmanager
    │
    └── enterprise-platform/dev/payment-service
46. Inspect Secret Consumption

Use:

grep -n -A15 -B5 "SPRING_DATASOURCE_USERNAME" \
  /tmp/payment-secret-auto.yaml

Confirm:

SPRING_DATASOURCE_USERNAME
        │
        ▼
payment-service-secret
        │
        ▼
database-username

Similarly verify:

SPRING_DATASOURCE_PASSWORD
        │
        ▼
payment-service-secret
        │
        ▼
database-password

and:

JWT_SECRET
        │
        ▼
payment-service-secret
        │
        ▼
jwt-secret
47. Verify AWS Secret

The actual value should not be printed unnecessarily.

Verify that the secret exists:

aws secretsmanager describe-secret \
  --secret-id enterprise-platform/dev/payment-service \
  --region us-east-1

Verify the version:

aws secretsmanager list-secret-version-ids \
  --secret-id enterprise-platform/dev/payment-service \
  --region us-east-1

The expected current version should have:

AWSCURRENT
48. Important Security Rule

Do NOT use commands that unnecessarily print secret values to the terminal or CI logs.

Avoid:

aws secretsmanager get-secret-value ...

unless there is a specific reason and the output is protected.

Never commit:

passwords
JWT secrets
database credentials
API keys
private keys

to Git.

Never put actual secret values inside:

values.yaml
values-dev.yaml
Jenkinsfile
Dockerfile
GitHub Actions YAML
Kubernetes Secret YAML

The Git repository should contain references, not secret material.

49. Secret Rotation

The architecture supports secret rotation.

When the value changes in AWS Secrets Manager:

AWS Secrets Manager
        │
        ▼
External Secrets Operator
        │
        ▼
Kubernetes Secret

The ExternalSecret refresh interval determines how frequently synchronization occurs.

Example:

refreshInterval: 1h

Applications may need to restart or otherwise reload configuration depending on how the application consumes the secret.

This should be addressed as part of the production secret-rotation strategy.

50. Database Credentials

Database credentials follow the same secret architecture.

For example:

enterprise-platform/dev/payment-service

may eventually contain:

{
  "database-username": "...",
  "database-password": "...",
  "database-url": "...",
  "jwt-secret": "..."
}

However, the actual database itself is NOT part of the Application Golden Path.

Database infrastructure belongs to the Database Golden Path.

51. Application Golden Path vs Database Golden Path

These are separate platform capabilities.

Application Golden Path

Responsible for:

Application
Deployment
Service
HPA
Ingress
Health
Metrics
Logs
Secrets consumption
Database Golden Path

Responsible for:

Database provisioning
Database engine
Database version
Instance size
Storage
Networking
Security groups
Encryption
Backups
Maintenance
High availability
Monitoring
Credentials
Connection information

The two paths work together.

52. Future Database Integration

The intended architecture is:

                 Application Golden Path
                          │
                          │
                          ▼
                  payment-service
                          │
                          │ database connection
                          ▼
                 Database Golden Path
                          │
                          ▼
                    RDS PostgreSQL

The database should not be manually created every time a developer needs one.

Instead, the platform should eventually provide a standardized database provisioning workflow.

53. Future Database Configuration

A future application could declare something conceptually like:

database:
  enabled: true

  engine: postgres

  version: "16"

  instanceClass: db.t3.micro

  storage:
    size: 20
    type: gp3

  backup:
    retentionDays: 7

  highAvailability:
    enabled: false

The platform would translate this into the approved infrastructure pattern.

The exact schema will be defined when the Database Golden Path is implemented.

54. Database Secrets

The Database Golden Path should integrate with the existing secrets architecture.

For example:

RDS PostgreSQL
      │
      │ credentials
      ▼
AWS Secrets Manager
      │
      ▼
External Secrets Operator
      │
      ▼
Kubernetes Secret
      │
      ▼
Application

This avoids creating a separate secret-management model for databases.

55. Why the Database Path Should Be Separate

Application deployment and database provisioning have different lifecycles.

Applications may be deployed:

multiple times per day

while databases may require controlled infrastructure changes.

For example:

Application
    └── image update

Database
    └── instance resize
    └── storage change
    └── version upgrade
    └── backup policy
    └── network change

Keeping these capabilities logically separated provides safer lifecycle management.

56. Golden Path Evolution

The eventual platform should provide multiple Golden Paths.

Enterprise Platform
        │
        ├── Application Golden Path
        │
        ├── Database Golden Path
        │
        ├── Messaging Golden Path
        │
        ├── Cache Golden Path
        │
        └── Observability Golden Path

Developers consume platform capabilities rather than rebuilding infrastructure.

57. Observability as a Platform Capability

Prometheus, Loki, Grafana and Alertmanager are platform-level capabilities.

They should not be installed separately for each application.

The relationship is:

                    Platform
                       │
       ┌───────────────┼────────────────┐
       │               │                │
   Prometheus         Loki           Grafana
       │               │                │
       │               │                │
       └───────────────┴────────────────┘
                       │
                  Applications

Applications integrate into the existing platform.

58. Current Observability Status

The broader Enterprise Platform architecture has already established:

Prometheus
Loki
Grafana
Alertmanager

as the intended observability stack.

The Application Golden Path therefore integrates applications into this platform rather than attempting to own the monitoring infrastructure.

The remaining work should be treated as validation and hardening of the application integration rather than redesigning the observability architecture.

59. Troubleshooting Lessons
59.1 External Secrets API Version

An earlier External Secrets deployment encountered a mismatch where the manifests referenced:

external-secrets.io/v1beta1

while the installed CRDs supported:

external-secrets.io/v1

This caused ArgoCD synchronization failures.

Lesson:

Always verify the CRD/API version installed in the target cluster before writing platform manifests.

60. Helm .Files.Get vs tpl

Monitoring configuration previously encountered an issue where Helm read a configuration file using:

.Files.Get

but embedded Helm expressions were not evaluated.

The solution was:

tpl (.Files.Get "alertmanager/config.yaml") .

Lesson:

.Files.Get reads file content, while tpl allows Helm to evaluate templates contained inside that content.

61. Missing Values

Helm previously produced errors such as:

nil pointer evaluating interface {}.smtp

This occurred because a referenced values structure did not exist.

Lesson:

Platform templates should validate required values and provide safe defaults where appropriate.

62. YAML Indentation

ExternalSecret configuration also encountered YAML indentation errors.

For example:

- secretKey: smtp-from
  remoteRef:
    key: ...
    property: smtp-from

must maintain correct indentation.

Lesson:

Always render and lint Helm templates before committing platform changes.

63. Golden Path Design Principles

The Application Golden Path should follow these principles.

Principle 1 — Secure by Default

Secrets should never be stored in Git.

Principle 2 — Fail Fast

Invalid configuration should fail during Helm rendering.

Principle 3 — Developer Simplicity

Developers should configure values rather than write infrastructure.

Principle 4 — Platform Ownership

The platform owns reusable infrastructure patterns.

Principle 5 — GitOps

Desired state belongs in Git.

Principle 6 — Observability by Default

Applications should integrate with platform monitoring.

Principle 7 — Least Privilege

Applications should only receive the permissions they require.

Principle 8 — Environment Consistency

The same application pattern should work across:

dev
staging
production

with environment-specific values.

Principle 9 — Reproducibility

A service should be deployable repeatedly using the same template.

Principle 10 — Self-Service

The ultimate goal is for developers to consume the platform without requiring manual platform-engineering intervention for normal application onboarding.

64. Application Onboarding Flow

The future ideal developer workflow is:

1. Create application
        │
        ▼
2. Create Dockerfile
        │
        ▼
3. Push application code
        │
        ▼
4. Jenkins builds and scans
        │
        ▼
5. Image pushed to ECR
        │
        ▼
6. Create application values
        │
        ▼
7. Create required AWS secrets
        │
        ▼
8. Register ArgoCD Application
        │
        ▼
9. ArgoCD syncs
        │
        ▼
10. Kubernetes creates resources
        │
        ▼
11. External Secrets synchronizes credentials
        │
        ▼
12. Prometheus discovers metrics
        │
        ▼
13. Loki receives logs
        │
        ▼
14. Grafana visualizes application
65. Example: Payment Service

The payment service demonstrates the intended pattern.

Application:

payment-service

Environment:

dev

AWS secret:

enterprise-platform/dev/payment-service

Kubernetes Secret:

payment-service-secret

Secret properties:

database-username
database-password
jwt-secret

Application environment variables:

SPRING_DATASOURCE_USERNAME
SPRING_DATASOURCE_PASSWORD
JWT_SECRET

This gives us the following complete chain:

AWS Secrets Manager
enterprise-platform/dev/payment-service
            │
            ▼
ExternalSecret
            │
            ▼
payment-service-secret
            │
            ▼
Deployment
            │
            ▼
payment-service Pod
66. Validation Checklist

Before considering an application successfully onboarded, verify:

Helm
helm lint charts/service-template

Expected:

0 chart(s) failed
Rendering
helm template payment-service charts/service-template \
  -f charts/service-template/values/payment-service-dev.yaml

Verify that expected resources render.

Deployment

Verify:

Deployment
Service
ServiceAccount
HPA
Ingress

If enabled, verify:

Ingress
Secrets

Verify:

ClusterSecretStore
ExternalSecret
Kubernetes Secret
AWS

Verify:

AWS Secrets Manager secret exists
AWSCURRENT version exists
Application

Verify:

Pod Running
Readiness = healthy
Liveness = healthy
Metrics

Verify:

/actuator/prometheus
ServiceMonitor
Prometheus target
Logs

Verify:

application logs
Loki
Grafana
67. Definition of Done

The Application Golden Path is considered complete when a new application can be deployed using the standardized template without manually creating application-specific Kubernetes manifests.

Minimum capabilities:

[✓] Helm chart
[✓] Deployment
[✓] Service
[✓] ServiceAccount
[✓] Health probes
[✓] Resource configuration
[✓] HPA
[✓] Optional Ingress
[✓] Secret references
[✓] AWS Secrets Manager integration
[✓] External Secrets Operator integration
[✓] ClusterSecretStore
[✓] ExternalSecret
[✓] Fail-fast Helm validation
[✓] Prometheus integration
[✓] GitOps / ArgoCD integration
[✓] Environment-specific values

Additional observability validation:

[ ] Loki integration fully validated for the template
[ ] Grafana dashboards standardized for every application
[ ] Standard application alert rules finalized
[ ] OpenTelemetry tracing standardized

These should be treated as observability hardening rather than reasons to redesign the application template.

68. Current Boundary

The Application Golden Path does NOT provision:

RDS
Redis
Kafka
SQS
SNS
S3

Those belong to other platform capabilities.

The Application Golden Path consumes these services.

For example:

Application
    │
    ├── consumes RDS
    ├── consumes Redis
    └── consumes S3

while the corresponding Golden Paths provision and manage them.

69. Next Platform Capability: Database Golden Path

The next major platform capability is:

Database Golden Path

The initial implementation should focus on:

AWS RDS PostgreSQL

It should eventually standardize:

Database engine
Database version
Instance class
Storage
Encryption
Networking
Security groups
Subnet groups
Backups
Maintenance
Monitoring
High availability
Credentials
Secrets Manager integration
Application connection configuration
70. Intended Final Developer Experience

The long-term goal is for a developer to describe an application and its dependencies declaratively.

Conceptually:

application:
  name: payment-service

  image:
    repository: ...
    tag: ...

database:
  enabled: true

  engine: postgres
  version: "16"

  storage:
    size: 20

secrets:
  enabled: true

observability:
  enabled: true

The platform then handles:

Application
      │
      ├── Kubernetes
      │
      ├── Secrets
      │
      ├── Database
      │
      ├── Monitoring
      │
      └── GitOps

This is the direction toward a true self-service internal developer platform.

71. Final Architecture

The long-term architecture is:

                         Developer
                             │
                             ▼
                    Application Definition
                             │
             ┌───────────────┼────────────────┐
             │               │                │
             ▼               ▼                ▼
       Application        Database        Observability
       Golden Path        Golden Path       Platform
             │               │                │
             ▼               ▼                ▼
        Kubernetes          RDS           Prometheus
        Deployment       PostgreSQL          Loki
        Service                              Grafana
        HPA                                  Alertmanager
        Ingress
        Secrets
             │               │
             └───────┬───────┘
                     ▼
                   EKS
                     │
                     ▼
                  ArgoCD
                     │
                     ▼
                GitOps State
                     │
                     ▼
                   AWS
72. Summary

The Application Golden Path establishes a standardized deployment contract for applications running on the Enterprise Platform.

The developer provides application-specific values.

The platform provides:

Kubernetes deployment patterns
Service networking
Health checks
Autoscaling
Ingress
Service identity
Secret integration
Prometheus integration
GitOps integration

Secrets are managed using:

AWS Secrets Manager
        ↓
External Secrets Operator
        ↓
Kubernetes Secret
        ↓
Application

The actual secret values are never stored in Git.

Observability is provided as a platform capability:

Prometheus → Metrics
Loki       → Logs
Grafana    → Visualization
Alertmanager → Alerts

The Application Golden Path is intentionally separate from database provisioning.

The next capability is therefore the:

Database Golden Path

which will provide a standardized and secure way for developers to request and consume databases such as PostgreSQL on Amazon RDS.

The overall platform direction is:

Application Golden Path
          +
Database Golden Path
          +
Observability Platform
          +
Security Platform
          +
GitOps
          =
Self-Service Enterprise Developer Platform

The guiding principle remains:

Make the secure, observable, reliable, and repeatable path the easiest path for developers.