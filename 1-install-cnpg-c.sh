#!/bin/sh
# https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/installation_upgrade/

set -a
source $HOME/cnpg-c/.env
set +a

# check $EDB_SUBSCRIPTION_TOKEN
if [ -z "$EDB_SUBSCRIPTION_TOKEN" ]; then
  echo "EDB_SUBSCRIPTION_TOKEN is not set. Please set it in the .env file."
  exit 1
fi

echo "Creating Operator and $NS_OPERATOR and $NS_EPAS namespaces..."
kubectl create ns $NS_OPERATOR
kubectl create ns $NS_EPAS 

echo "Creating image pull secret $SECRET_NAME..."
kubectl delete secret $SECRET_NAME -n $NS_OPERATOR --ignore-not-found=true 
kubectl create secret docker-registry $SECRET_NAME \
 --docker-server=$CLOUDSMITH \
 --docker-username=$CS_USER \
 --docker-password=$EDB_SUBSCRIPTION_TOKEN \
 -n $NS_OPERATOR

echo "Verifying secret..."
kubectl get secret $SECRET_NAME -n $NS_OPERATOR

echo "Applying CNPG-C manifest $CNPG_VERSION..."
kubectl apply --server-side -f https://get.enterprisedb.io/pg4k/pg4k-$CNPG_VERSION.yaml

echo "Waiting for operator to be ready..."
kubectl rollout status deployment/postgresql-operator-controller-manager -n $NS_OPERATOR --timeout=300s

echo "CloudNativePG operator installation complete!"
kubectl get pods -n $NS_OPERATOR

./kind/install-minio.sh
