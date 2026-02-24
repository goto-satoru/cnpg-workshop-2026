#!/bin/bash

set -a
source ./.env
set +a

echo "Deploying EPAS 16 cluster..."

# kubectl create secret docker-registry $SECRET_NAME \
#  --docker-server=$CLOUDSMITH \
#  --docker-username=$CS_USER \
#  --docker-password=$EDB_SUBSCRIPTION_TOKEN \
#  -n $NS_EPAS

kubectl apply -f cluster-barman.yaml

echo "" 
echo "Run following to monitor the cluster creation process:"
echo ""
echo "kubectl cnp status epas16 -n $NS_EPAS"
echo "watch kubectl cnp status epas16 -n $NS_EPAS"


# echo "Patching EPAS 16 service to use NodePort..."
# kubectl patch svc epas16-rw -n $NS_EPAS -p '{"spec": {"type": "NodePort","ports":[{"port":5432,"targetPort":5432,"nodePort":30432}'
