#!/bin/bash

set -a
source ./.env
set +a

echo "Deploying EPAS 16.13 cluster..."

kubectl create secret docker-registry $SECRET_NAME \
 --docker-server=$CLOUDSMITH \
 --docker-username=$CS_USER \
 --docker-password=$EDB_SUBSCRIPTION_TOKEN \
 -n $NS_EPAS

# kubectl apply -f 02-cluster-16.13-wo-bak.yaml
kubectl apply -f 02-cluster-16.13.yaml

echo "" 
echo "Run following to monitor the cluster creation process:"
echo ""
echo "kubectl cnp status epas16 -n $NS_EPAS"
echo "watch kubectl cnp status epas16 -n $NS_EPAS"
