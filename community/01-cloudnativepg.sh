#!/bin/sh
# https://cloudnative-pg.io/docs/1.25/installation_upgrade

NS_OPERATOR=cnpg-system
NS_PG=postgres
CNPG_VERSION=1.28.4

echo "Creating Operator and $NS_OPERATOR and $NS_PG namespaces..."
kubectl create ns $NS_OPERATOR
kubectl create ns $NS_PG 

echo "-------------------------------------------------------------------------"
echo "Applying CNPG manifest $CNPG_VERSION..."
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.28/releases/cnpg-$CNPG_VERSION.yaml

echo "Waiting for operator to be ready..."
kubectl rollout status deployment/postgresql-operator-controller-manager -n $NS_OPERATOR --timeout=300s

echo "CloudNativePG operator installation complete!"
kubectl get po -n $NS_OPERATOR

../silo/install-silo.sh

echo ""
echo "CloudNativePG $CNPG_VERSION and Silo setup complete!"
echo "---"
echo "Run following to monitor the CloudNativePG deployment:"
echo "kubectl rollout status deployment postgresql-operator-controller-manager -n $NS_OPERATOR"
echo "" 
