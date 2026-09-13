1. ArgoCD 

domain url :  https://argocd.dev.dreammyles.online/

initial admin password

Run:

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo

Username:

admin

If you want to verify the secret exists:

kubectl -n argocd get secret argocd-initial-admin-secret
2. Check the ArgoCD service

Run:

kubectl get svc -n argocd

You'll probably see something like:

argocd-server   ClusterIP   ...

Because it's currently internal, you won't be able to simply browse to it from the Internet yet.

For a quick test, you can port-forward:

kubectl port-forward svc/argocd-server -n argocd 8080:443

Then from the machine where the port-forward is running:

https://localhost:8080

Login:

Username: admin
Password: <password from above>
3. Grafana initial password

To check grafana on web :  grafana.dev.dreammyles.online


First check the Grafana secret:

kubectl get secret -n monitoring grafana-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo

Username is normally:

admin

Check the service:


kubectl get svc -n monitoring | grep -i grafana

Then port-forward using the actual service name returned:

kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80

Open:

http://localhost:3000

Login:

Username: admin
Password: <password from secret>
4. Prometheus

First find the service:

kubectl get svc -n monitoring | grep -i prometheus

You'll likely have something similar to:

prometheus-stack-kube-prom-prometheus

Then:

kubectl port-forward -n monitoring \
  svc/prometheus-stack-kube-prom-prometheus 9090:9090

Open:

http://localhost:9090

Prometheus normally doesn't require a username/password in this setup.

Try:

up

and:

kube_node_info
5. Alertmanager

Find its service:

kubectl get svc -n monitoring | grep -i alert

Then, depending on the service name, for example:

kubectl port-forward -n monitoring \
  svc/prometheus-stack-kube-prom-alertmanager 9093:9093

Open:

http://localhost:9093
6. About dreammylesonline.dev.argocd

This is the important part.

If your intended architecture is something like:

dreammylesonline.dev.argocd
dreammylesonline.dev.grafana
dreammylesonline.dev.prometheus
dreammylesonline.dev.alertmanager

we need to distinguish DNS from Ingress.

DNS alone doesn't make these services accessible.

The eventual flow should be approximately:

Browser
   |
   v
Route 53
   |
   +---- dreammylesonline.dev.argocd
   |              |
   |              v
   |        AWS Load Balancer
   |              |
   |              v
   |        ArgoCD Service
   |
   +---- dreammylesonline.dev.grafana
   |              |
   |              v
   |        AWS Load Balancer
   |              |
   |              v
   |           Grafana
   |
   +---- dreammylesonline.dev.prometheus
                  |
                  v
           AWS Load Balancer
                  |
                  v
              Prometheus

However, before we start creating public DNS records, let's inspect what your GitOps networking layer has already created.

Run these three commands:

kubectl get ingress -A
kubectl get svc -A
kubectl get certificates -A

And also:

kubectl get applications -n argocd

Your current ArgoCD status shows that networking and storage are healthy, while the AWS Load Balancer Controller is currently Degraded and several observability applications are still progressing/degraded. So I would not expose Grafana/Prometheus publicly yet.

The next thing I want to see is whether your existing GitOps repo has already defined the intended hostnames/Ingress resources. Then we can use your existing platform design rather than creating a second networking approach.