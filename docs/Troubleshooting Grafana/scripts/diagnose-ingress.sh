#!/bin/bash

set -e

echo "========================================"
echo "Enterprise Platform Diagnostics"
echo "========================================"

echo
echo "Current kubectl context:"
kubectl config current-context

echo
echo "Current AWS identity:"
aws sts get-caller-identity

echo
echo "Current ACM certificate:"
aws acm list-certificates --region us-east-1

echo
echo "ArgoCD Applications"
kubectl get applications -n argocd

echo
echo "Monitoring Ingress"
kubectl get ingress -n monitoring

echo
echo "Monitoring Services"
kubectl get svc -n monitoring

echo
echo "Monitoring Pods"
kubectl get pods -n monitoring

echo
echo "Grafana Ingress Details"
kubectl describe ingress prometheus-stack-grafana -n monitoring

echo
echo "Auth Ingress Details"
kubectl describe ingress auth-service -n auth

echo
echo "AWS Load Balancer Controller"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

echo
echo "Recent Ingress Events"
kubectl get events -A \
  --field-selector involvedObject.kind=Ingress \
  --sort-by=.lastTimestamp | tail -3=]
  .,