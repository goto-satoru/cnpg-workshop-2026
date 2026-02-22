#!/bin/bash

set -a
source .env
set +a

# env | sort

echo "Deploying EPAS 16 cluster..."
kubectl apply -f cluster-barman.yaml
# kubectl apply -f cluster.yaml

# Patch epas16-rw service to NodePort

# wait for the cluster to be ready
echo "Waiting for EPAS 16 cluster to be ready..."

sleep 60 # initial wait before checking status
kubectl wait --for=condition=Available=True --timeout=600s deployment/epas16-rw -n $NS_EPAS

# env | sort 

kubectl create secret docker-registry $SECRET_NAME \
 --docker-server=$CLOUDSMITH \
 --docker-username=$CS_USER \
 --docker-password=$EDB_SUBSCRIPTION_TOKEN \
 -n $NS_EPAS

echo "Patching EPAS 16 service to use NodePort..."
kubectl patch svc epas16-rw -n $NS_EPAS -p '{"spec": {"type": "NodePort","ports":[{"port":5432,"targetPort":5432,"nodePort":30432}'