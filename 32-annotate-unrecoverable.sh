#!/bin/sh

echo "annotating pod $1 as alpha.k8s.enterprisedb.io/unrecoverable=true"
kubectl annotate pod $1 alpha.k8s.enterprisedb.io/unrecoverable=true

kubectl get pod $1 -o yaml | grep unrecoverable
