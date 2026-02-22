#!/bin/sh

helm repo add prometheus https://prometheus-community.github.io/helm-charts
helm repo update prometheus

helm upgrade --install -n postgresql-operator-system \
  -f https://raw.githubusercontent.com/EnterpriseDB/docs/main/product_docs/docs/postgres_for_kubernetes/1/samples/monitoring/kube-stack-config.yaml \
  prometheus prometheus/kube-prometheus-stack
