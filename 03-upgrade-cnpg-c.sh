#!/bin/sh
# https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/installation_upgrade/

set -a
source ./.env
set +a

export CNPG_VERSION=1.28.5
SELECTOR="k8s.enterprisedb.io/cluster=epas16"
NS=edb

# check $EDB_SUBSCRIPTION_TOKEN
if [ -z "$EDB_SUBSCRIPTION_TOKEN" ]; then
  echo "EDB_SUBSCRIPTION_TOKEN is not set. Please set it in the .env file."
  exit 1
fi

echo "Upgrading EDB CNPG Cluster Operator $CNPG_VERSION in $NS_OPERATOR and $NS_EPAS namespaces..."
echo ""
kubectl create ns $NS_OPERATOR
kubectl create ns $NS_EPAS 

echo "-------------------------------------------------------------------------"
echo "Applying CNPG-C manifest $CNPG_VERSION..."
kubectl apply --server-side -f https://get.enterprisedb.io/pg4k/pg4k-$CNPG_VERSION.yaml

echo "Waiting for operator to be ready..."
kubectl rollout status deployment/postgresql-operator-controller-manager -n $NS_OPERATOR --timeout=300s

echo "CloudNativePG operator upgrade complete!"
kubectl get pods -n $NS_OPERATOR

echo "check EPAS pod uid:"
echo "oc get pods -n $NS -l $SELECTOR -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,CONTAINER:.status.containerStatuses[*].name,CONTAINER_ID:.status.containerStatuses[*].containerID,NODE:.spec.nodeName'"
