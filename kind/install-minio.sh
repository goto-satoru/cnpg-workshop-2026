#!/bin/sh

source ../.env 

if helm repo ls | grep -q minio; then
    echo "MinIO Helm repository already exists. Skipping addition."
else
    helm repo add minio https://charts.min.io/
fi
helm repo update minio

helm upgrade --install minio minio/minio \
    --create-namespace \
    --namespace edb \
    --set mode=standalone \
    --set rootUser=$MINIO_ROOT_USER \
    --set rootPassword=$MINIO_ROOT_PASSWORD \
    --set resources.requests.memory=256Mi \
    --set resources.limits.memory=512Mi \
    --set persistence.enabled=true \
    --set persistence.size=5Gi \
    --set service.type=ClusterIP \
    --set consoleService.type=ClusterIP \
    --set replicas=1 


