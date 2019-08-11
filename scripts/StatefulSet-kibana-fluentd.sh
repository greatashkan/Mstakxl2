#!/bin/bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl -f apply /yaml/elasticsearch_statefulset.yaml
sleep 120

kubectl f apply /yaml/kibana.yaml
kubectl f apply /yaml/fluentd.yaml
