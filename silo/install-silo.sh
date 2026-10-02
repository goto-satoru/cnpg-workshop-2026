#!/bin/sh

if [ -f ./.env ]; then
    source ./.env
elif [ -f ../.env ]; then
    source ../.env
fi

NS_PG=$NS_EPAS

helm repo add minio https://charts.min.io/
helm repo update minio

helm upgrade --install silo minio/minio \
  --namespace $NS_PG --create-namespace \
  --set mode=standalone \
  --set replicas=1 \
  --set image.repository=pgsty/silo \
  --set image.tag=RELEASE.2026-09-16T00-00-00Z \
  --set mcImage.repository=pgsty/mc \
  --set mcImage.tag=RELEASE.2026-09-16T00-00-00Z \
  --set rootUser=silo_admin \
  --set rootPassword=silo_passwd_1615 \
  --set persistence.size=5Gi \
  --set resources.requests.memory=256Mi \
  --set resources.limits.memory=512Mi
