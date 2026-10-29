# Migration Runtime and Platform Environment

**Repository:** `enterprise-platform-gitops`  
**Status:** Implemented and end-to-end verified  
**Date:** September 2026

## 1. Purpose

This document records the GitOps implementation of controlled database migration and the platform environment refactor.

```text
Application SQL
  ↓
Jenkins
  ↓
S3 artifact
  ↓
Argo CD
  ↓
Migration Job
  ↓
Flyway
  ↓
PostgreSQL
```

## 2. Migration Values Contract

The chart supports:

```yaml
migration:
  enabled: false
  engine: flyway
  artifact:
    bucket: ""
    key: ""
  image:
    repository: flyway/flyway
    tag: "10.10.0"
  serviceAccount:
    name: ""
    roleArn: ""
  securityGroupPolicy:
    enabled: false
    groupId: ""
  databaseSecret:
    name: ""
    secretStore: aws-secretsmanager
```

## 3. Migration Job

The migration Job renders only when migration is enabled, an artifact key exists, and the selected engine is Flyway.

The Job uses:

```text
amazon/aws-cli:2.37.4
flyway/flyway:10.10.0
```

## 4. Argo CD Ordering

The Job is an Argo CD PreSync hook:

```yaml
argocd.argoproj.io/hook: PreSync
argocd.argoproj.io/sync-wave: "10"
```

The intended lifecycle is:

```text
Argo CD sync
  ↓
Migration prerequisites
  ↓
Migration Job
  ↓
Flyway success
  ↓
Application deployment
```

## 5. Migration Prerequisites

The migration workload receives its own:

- ServiceAccount
- SecurityGroupPolicy
- ExternalSecret
- workload identity
- database credential Secret

These are platform-managed. The application SQL is not.

## 6. Artifact Download

The init container runs:

```bash
aws s3 sync \
  "s3://<bucket>/<migration-path>/" \
  /migration/db/migration/ \
  --exclude "*" \
  --include "*.sql"
```

Downloaded SQL is mounted into the Flyway container.

## 7. Flyway Execution

Flyway executes against the platform-resolved PostgreSQL endpoint using credentials read from the Kubernetes Secret.

## 8. Debugging Hook Cleanup

During troubleshooting, automatic successful-hook cleanup and the short Job TTL were temporarily disabled so failed Jobs could be inspected.

After successful validation, the intended cleanup is:

```yaml
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
ttlSecondsAfterFinished: 300
```

## 9. IAM Failure

The first migration Job reached S3 but failed because the migration role lacked `s3:ListBucket`. This was correctly fixed in `enterprise-platform-infra`; the GitOps workload definition did not need to bypass AWS authorization.

## 10. Successful Migration

The migration Job downloaded:

```text
V1__initial_auth_schema.sql
V2__add_phone_number.sql
```

Flyway reported:

```text
Successfully validated 2 migrations
Migrating schema to version 1 - initial auth schema
Migrating schema to version 2 - add phone number
Successfully applied 2 migrations to schema "public", now at version v2
```

On subsequent application startup, Flyway reported the schema was already at V2 and no migration was necessary.

This proved the controlled migration lifecycle end-to-end.

## 11. Platform Environment Refactor

The generic deployment template previously injected:

```yaml
- name: SPRING_PROFILES_ACTIVE
  value: {{ .Values.application.profile | quote }}
```

It now injects:

```yaml
- name: APP_ENV
  value: {{ .Values.global.environment | quote }}
```

The platform environment is therefore generic across Spring Boot, Node.js, Python, Go, and other runtimes.

Framework-specific profile behavior remains an application implementation concern.

## 12. GitOps Environment Publishing Incident

`platform/environments/dev.yaml` contains:

```yaml
environment: dev

artifactStore:
  bucket: enterprise-platform-dev-artifacts
```

A previous pipeline run read Terraform output from the wrong context and produced `Warning: No outputs found`, which corrupted generated configuration.

The environment file was restored. The application pipeline now validates that `artifactStore.bucket` exists before using it.

## 13. Generic-Template Cleanup

The Auth Service chart still contains an old `application.profile` value that is no longer consumed by the deployment template. It was intentionally left in place while the APP_ENV path was deployed and verified.

The generic service template should remove framework-specific profile configuration after the new environment contract is fully adopted.

## 14. Final GitOps Runtime Path

```text
Application migration SQL
        ↓
Jenkins
        ↓
S3 artifact
        ↓
GitOps values
        ↓
Argo CD
        ↓
ServiceAccount / SG Policy / ExternalSecret
        ↓
Migration Job
        ↓
Flyway
        ↓
PostgreSQL
        ↓
Application
```

## 15. Next GitOps Direction

Move reusable migration behavior into the generic `service-template` so Auth Service becomes a consumer/reference implementation rather than the owner of a special migration chart.

Then validate the template with a second runtime without copying Auth Service-specific AWS configuration.
