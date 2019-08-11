#!/bin/bash


export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl create -f /yaml/elasticsearch_svc.yaml
kubectl create -f /yaml/stclass.yaml

mkdir /mnt/elastic
mkdir /mnt/elastic1
mkdir /mnt/elastic2

Kubectl apply f /yaml/pv-volume1.yaml
Kubectl apply f /yaml/pv-volume2.yaml
Kubectl apply f /yaml/pv-volume3.yaml


