#!/bin/sh
# https://cloudnative-pg.io/docs/1.25/installation_upgrade

NS_OPERATOR=cnpg-system
NS_PG=postgres
CNPG_VERSION=1.25.0

echo "Creating Operator and $NS_OPERATOR and $NS_PG namespaces..."
kubectl create ns $NS_OPERATOR
kubectl create ns $NS_PG 

echo "-------------------------------------------------------------------------"
echo "Applying CNPG manifest $CNPG_VERSION..."
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.25/releases/cnpg-$CNPG_VERSION.yaml

echo "Waiting for operator to be ready..."
kubectl rollout status deployment/postgresql-operator-controller-manager -n $NS_OPERATOR --timeout=300s

echo "CloudNativePG operator installation complete!"
kubectl get pods -n $NS_OPERATOR

./minio/install-minio.sh

echo ""
echo "CNPG Cluster and MinIO setup complete!"
echo "---"
echo "Run following to monitor the CNPG Cluster deployment:"
echo "kubectl rollout status deployment postgresql-operator-controller-manager -n $NS_OPERATOR"
echo "" 
