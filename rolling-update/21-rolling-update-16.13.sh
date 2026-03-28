#!/bin/bash

set -a
source ../.env
set +a

echo "Start rolloing update EPAS 16.11 -> 16.13 ..."

kubectl create secret docker-registry $SECRET_NAME \
 --docker-server=$CLOUDSMITH \
 --docker-username=$CS_USER \
 --docker-password=$EDB_SUBSCRIPTION_TOKEN \
 -n $NS_EPAS

cat <<EOF | kubectl apply -f -
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Cluster
metadata:
  name: epas16
  namespace: edb
spec:
  # Primary update strategy - unsupervised (default) or supervised https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/installation_upgrade/
  primaryUpdateStrategy: supervised
  instances: 3
  #                                                            !!!!! the latest
  imageName: docker.enterprisedb.com/k8s/edb-postgres-advanced:16.13
  imagePullSecrets:
  - name: edb-pull-secret
  storage:
    size: 1Gi
EOF

echo "" 
echo "Run following to monitor the cluster creation process:"
echo ""
echo "kubectl cnp status epas16 -n $NS_EPAS"
echo "watch kubectl cnp status epas16 -n $NS_EPAS"
echo ""
echo ""promote one of replias to primary and check the cluster status again""
echo "kubectl -n $NS_EPA cnp promote epas16 repas16-2"
echo "or "
echo "kubectl -n $NS_EPA cnp promote epas16 repas16-3"
