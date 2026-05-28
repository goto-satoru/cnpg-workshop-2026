#!/bin/bash

set -a
source ./.env
set +a

echo "Deploying EPAS $EPAS_VERSION cluster..."

oc create secret docker-registry $SECRET_NAME \
 --docker-server=$CLOUDSMITH \
 --docker-username=$CS_USER \
 --docker-password=$EDB_SUBSCRIPTION_TOKEN \
 -n $NS_EPAS

oc apply -f 02-cluster-$EPAS_VERSION.yaml

echo "" 
echo "Run following to monitor the cluster creation process:"
echo ""
echo "oc cnp status epas16 -n $NS_EPAS"
echo "watch oc cnp status epas16 -n $NS_EPAS"
