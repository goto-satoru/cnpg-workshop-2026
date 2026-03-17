#!/bin/sh
# https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/installation_upgrade/

set -a
source ./.env
set +a

kubectl delete -f https://get.enterprisedb.io/pg4k/pg4k-$CNPG_VERSION.yaml --ignore-not-found=true

echo "Deleting namespaces..."
kubectl delete ns $NS_OPERATOR
kubectl delete ns $NS_EPAS 
