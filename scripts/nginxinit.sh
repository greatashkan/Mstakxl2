#!/bin/bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl create deployment nginx --image=nginx -n development
kubectl apply f /yaml/servicemonitor.yaml


