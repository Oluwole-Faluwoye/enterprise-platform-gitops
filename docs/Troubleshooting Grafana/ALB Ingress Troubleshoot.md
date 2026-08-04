Grafana / ALB Ingress Troubleshooting
Issue

After destroying and recreating the EKS cluster, Grafana (grafana.dev.dreammyles.online) and the Auth Service were inaccessible.

The Ingress never received an ALB address.

Example:

kubectl get ingress -n monitoring

Output:

ADDRESS:
<empty>
Symptoms
kubectl describe ingress prometheus-stack-grafana -n monitoring

showed:

CertificateNotFound:
Certificate 'arn:aws:acm:...:certificate/OLD_CERTIFICATE_ID' not found

and

services "prometheus-stack-grafana" not found

ArgoCD also remained:

Sync Status : OutOfSync
Health      : Progressing

waiting on:

waiting for healthy state of networking.k8s.io/Ingress/prometheus-stack-grafana
Root Cause

The old ACM certificate had been destroyed with the previous infrastructure.

Although Terraform created a new ACM certificate, one or more GitOps Helm values files still referenced the old certificate ARN.

Because ArgoCD continually reconciled the old manifest, the AWS Load Balancer Controller repeatedly attempted to create an ALB using a certificate that no longer existed.

As a result:

No ALB was created
No DNS record was updated
Grafana remained inaccessible
ArgoCD became stuck in a reconciliation loop
Resolution
Updated all GitOps Helm charts to use the new ACM certificate ARN.
Modified the Jenkins pipeline to automatically update every chart containing:
alb.ingress.kubernetes.io/certificate-arn
The existing ArgoCD Application became stuck in reconciliation.

-----------------------------------------------------------------------------------
To recover it:

kubectl delete application prometheus-stack \
-n argocd \
--cascade=orphan

-------------------------------------------------------------------------------------
ArgoCD automatically recreated the Application from Git.

The recreated Application generated a fresh Ingress using the correct ACM certificate.

Verification:

kubectl describe ingress prometheus-stack-grafana -n monitoring

Expected:

Address:
k8s-xxxxxxxx.us-east-1.elb.amazonaws.com

Events:
Successfully reconciled


----------------------------------------------------------------------------------1. Create the file
mkdir -p scripts
nano scripts/diagnose-ingress.sh

or if you're using VS Code, simply create:

scripts/diagnose-ingress.sh

Paste the script into it.

2. Make it executable
chmod +x scripts/diagnose-ingress.sh

You only need to do this once.

3. Run it

From the root of your project:

./scripts/diagnose-ingress.sh

or

bash scripts/diagnose-ingress.sh

Both commands do the same thing.