#!/bin/bash

set -a
source ./.env
set +a

echo "Start rolloing update EPAS 16.11 -> 16.13 ..."

kubectl create secret docker-registry $SECRET_NAME \
 --docker-server=$CLOUDSMITH \
 --docker-username=$CS_USER \
 --docker-password=$EDB_SUBSCRIPTION_TOKEN \
 -n $NS_EPAS

kubectl apply -f 21-rolling-update.yaml -n $NS_EPAS

echo "" 
echo "Run following to monitor the cluster creation process:"
echo ""
echo "kubectl cnp status epas16 -n $NS_EPAS"
echo "watch kubectl cnp status epas16 -n $NS_EPAS"
