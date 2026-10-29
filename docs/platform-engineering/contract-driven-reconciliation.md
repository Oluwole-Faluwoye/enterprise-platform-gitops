# Contract-Driven GitOps Reconciliation

**Updated:** 14 October 2026  
**Repository:** `enterprise-platform-gitops`

## Purpose

This repository holds the declarative Kubernetes/Helm configuration consumed by Argo CD. The shared platform reconciler updates the relevant service values from a resolved service contract, so CI pipelines do not each maintain their own set of ad hoc YAML edits.

The reconciler and its CLI currently live in `enterprise-microservices/platform-ci`; this document explains the GitOps repository's role in that flow.

## Inputs and outputs

**Input:** `gitops-service-contract.json`, published by the infrastructure pipeline to the environment-specific S3 key:

`platform-contract/<environment>/gitops-service-contract.json`

The contract is a direct map keyed by service name. For example, the auth service is addressed as `."auth-service"`, not `."services"."auth-service"`.

**Output:** changes to the appropriate service chart values file, such as `charts/auth-service/values-dev.yaml`, based on the resolved contract and any build-specific overrides.

Values may include service/environment identity, database settings, workload identity, security-group references, and migration configuration. The reconciler also supports passing a build image tag and a migration artifact key from CI.

## Safe invocation

From the `enterprise-microservices` repository, run the shared CLI against a disposable GitOps clone first:


./platform-ci/bin/platform reconcile-gitops \
  /path/to/gitops-service-contract.json \
  /path/to/disposable-gitops-clone \
  --dry-run \
  --image-tag test-build-001 \
  --migration-artifact-key auth-service/migrations/testcommit/db/migration


The migration override should only be supplied when the resolved service contract enables migrations. Use a representative contract fixture and disposable clone for local tests.

### Modes

- `--dry-run` is the default. It stages candidate edits, validates the Helm configuration, and shows a diff without changing the target GitOps files.
- `--write` writes the reconciled values to the local clone. It does not commit or push.
- Commit/push and Argo CD deployment are separate actions and are not performed by the reconciler.

## Validation already performed

The following was tested using disposable directories and a fixture contract, not the live GitOps repository:

1. Dry-run with image tag `test-build-001` and migration key `auth-service/migrations/testcommit/db/migration`.
2. Helm validation passed.
3. The dry-run preview showed the image tag and migration artifact key.
4. A separate write-mode test updated `charts/auth-service/values-dev.yaml` in a disposable clone.
5. A second dry-run against that same clone showed no further changes, confirming idempotency for the fixture.

The auth-service Jenkins stage has now been changed to clone GitOps into a temporary workspace and call the reconciler in dry-run mode. It checks that the clone remains clean. Jenkins Pipeline lint and a real Jenkins build remain pending.

## Repository safety

- Do not run write mode against the working GitOps repository unless the changes are intended and reviewed.
- Do not commit/push changes as part of a test.
- Review the diff for the intended environment and service before promotion.
- Ensure the resolved contract belongs to the same environment as the values being reconciled.
- Treat the resolved contract as untrusted input: validate JSON and required fields before using it.
- Argo CD should deploy from the repository's committed state; a local reconciliation alone does not deploy anything.
