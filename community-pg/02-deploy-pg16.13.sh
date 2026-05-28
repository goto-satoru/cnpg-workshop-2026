#!/bin/bash

set -a
source ./.env
set +a

echo "Deploying Postgres $EPAS_VERSION cluster..."

kubectl apply -f 02-cluster-pg$EPAS_VERSION.yaml

echo "" 
echo "Run following to monitor the cluster creation process:"
echo ""
echo "kubectl cnp status pg16 -n $NS_EPAS"
echo "watch kubectl cnp status pg16 -n $NS_EPAS"
