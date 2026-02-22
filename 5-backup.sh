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


