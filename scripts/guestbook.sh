#!bin/bash
export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl create namespace development

kubectl apply -f https://k8s.io/examples/application/guestbook/redis-master-deployment.yaml -n development

kubectl apply -f https://k8s.io/examples/application/guestbook/redis-master-service.yaml -n development



