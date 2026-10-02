#!/bin/bash

NS_PG=postgres
CLUSTER=example

echo "Deploying Postgres cluster..."


kubectl apply -f cluster-pg.yaml

echo "" 
echo "Run following to monitor the cluster creation process:"
echo ""
echo "kubectl cnpg status $CLUSTER -n $NS_PG"
echo "watch kubectl cnpg status $CLUSTER -n $NS_PG"
