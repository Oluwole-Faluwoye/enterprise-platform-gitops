GitOps

Responsibility

Terraform manages AWS infrastructure.

ArgoCD manages Kubernetes workloads.

Canonical auth-service application

applications/auth-service.yaml

The chart is:

charts/auth-service

SecurityGroupPolicy

The chart contains:

templates/security-group-policy.yaml

The platform writes the resolved application SG ID into:

values-dev.yaml

Dynamic infrastructure values

Jenkins uses yq to update GitOps from Terraform outputs.

Examples include:

ALB IAM role

ExternalDNS IAM role

ACM certificate ARN

VPC ID

auth-service application SG

Validation

helm lint <chart>
helm template <chart>
kubectl get applications -n argocd