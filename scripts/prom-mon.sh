#!/bin/bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl create namespace monitoring

helm install stable/prometheus-operator --name prometheus-operator --namespace monitoring

kubectl port-forward -n monitoring prometheus-prometheus-operator-prometheus-0 9090 &
kubectl port-forward $(kubectl get pods --selector=app=grafana -n monitoring --output=jsonpath="{.items..metadata.name}") -n monitoring 3000 &

