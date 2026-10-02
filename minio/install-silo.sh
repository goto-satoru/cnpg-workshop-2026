#!/bin/sh

if [ -f ./.env ]; then
    source ./.env
elif [ -f ../.env ]; then
    source ../.env
fi

if helm repo ls | grep -q silo; then
    echo "Silo Helm repository already exists. Skipping addition."
else
    helm repo add silo https://charts.silo.run/
fi
helm repo update silo

helm upgrade --install silo silo/silo \
    --create-namespace \
    --namespace $NS_EPAS \
    --set mode=standalone \
    --set image.repository=docker.io/pgsty/silo \
    --set image.tag=latest \
    --set mode=standalone \
    --set auth.rootUser=$MINIO_ROOT_USER \
    --set auth.rootPassword=$MINIO_ROOT_PASSWORD \
    --set resources.requests.memory=256Mi \
    --set resources.limits.memory=512Mi \
    --set persistence.enabled=true \
    --set persistence.size=5Gi \
    --set service.type=ClusterIP \
    --set consoleService.type=ClusterIP \
    --set replicas=1 \
    --set livenessProbe=null \
    --set readinessProbe=null \
    --set postJob.enabled=false
