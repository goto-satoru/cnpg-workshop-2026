#!/bin/bash

DATETIME=$(date +%m%d-%H%M)

cat <<EOF | kubectl apply -f -
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Backup
metadata:
  name: backup-epas16-$DATETIME
  namespace: edb
spec:
  method: barmanObjectStore
  cluster:
    name: epas16
EOF

kubectl get backup -n edb 

echo ""
echo "you can take a backup also with kubectl cnp backup epas15 -n edb"
echo ""