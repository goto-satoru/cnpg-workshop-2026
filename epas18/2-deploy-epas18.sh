#!/bin/bash

set -a
source ../.env
set +a

echo "Deploying EPAS 18 cluster..."

kubectl create secret docker-registry $SECRET_NAME \
 --docker-server=$CLOUDSMITH \
 --docker-username=$CS_USER \
 --docker-password=$EDB_SUBSCRIPTION_TOKEN \
 -n $NS_EPAS

kubectl apply -f cluster-epas18.yaml

echo "" 
echo "Run following to monitor the cluster creation process:"
echo ""
echo "kubectl cnp status epas18 -n $NS_EPAS"
echo "watch kubectl cnp status epas18 -n $NS_EPAS"