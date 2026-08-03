#!/bin/bash

echo "========== ACM =========="
aws acm list-certificates --region us-east-1

echo
echo "========== Applications =========="
kubectl get applications -n argocd

echo
echo "========== Monitoring Ingress =========="
kubectl get ingress -n monitoring

echo
echo "========== Monitoring Services =========="
kubectl get svc -n monitoring

echo
echo "========== Ingress Details =========="
kubectl describe ingress prometheus-stack-grafana -n monitoring

echo
echo "========== Auth Ingress =========="
kubectl describe ingress auth-service -n auth

echo
echo "========== ALB Controller =========="
kubectl get pods -n kube-system | grep aws-load-balancer

echo
echo "========== Recent Ingress Events =========="
kubectl get events -A \
--field-selector involvedObject.kind=Ingress \
--sort-by=.lastTimestamp | tail -30