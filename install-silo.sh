#!/bin/sh

if [ -f ./.env ]; then
    source ./.env
elif [ -f ../.env ]; then
    source ../.env
fi

# Use local Silo Helm chart from ./silo directory
SILO_CHART_PATH="./silo"

if [ ! -d "$SILO_CHART_PATH" ]; then
    echo "Error: Silo Helm chart not found at $SILO_CHART_PATH"
    exit 1
fi

helm upgrade --install silo "$SILO_CHART_PATH" \
    --create-namespace \
    --namespace $NS_EPAS \
    --set mode=standalone \
    --set image.repository=pgsty/silo \
    --set image.tag=RELEASE.2026-09-16T00-00-00Z \
    --set rootUser=$MINIO_ROOT_USER \
    --set rootPassword=$MINIO_ROOT_PASSWORD \
    --set resources.requests.memory=256Mi \
    --set resources.limits.memory=512Mi \
    --set persistence.enabled=true \
    --set persistence.size=5Gi \
    --set service.type=ClusterIP \
    --set consoleService.type=ClusterIP \
    --set replicas=1 \
    --set livenessProbe=null \
    --set readinessProbe=null
