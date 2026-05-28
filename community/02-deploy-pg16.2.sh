#!/bin/bash

NS_PG=postgres
CLUSTER=pg16

echo "Deploying Postgres 16.2 cluster..."

kubectl apply -f 02-pg-16.2-wo-bak.yaml

echo "" 
echo "Run following to monitor the cluster creation process:"
echo ""
echo "kubectl cnpg status $CLUSTER -n $NS_PG"
echo "watch kubectl cnpg status $CLUSTER -n $NS_PG"
