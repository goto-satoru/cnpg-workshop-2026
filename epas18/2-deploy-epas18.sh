#!/bin/bash

set -a
source ../.env
set +a

echo "Deploying EPAS 18 cluster..."
kubectl apply -f cluster-epas18.yaml

# wait for the cluster to be ready
echo "Waiting for EPAS 18 cluster to be ready..."

sleep 60 # initial wait before checking status
kubectl wait --for=condition=Available=True --timeout=300s deployment/epas18-rw -n $NS_EPAS
