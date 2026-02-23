#!/bin/bash

set -a
source ./.env
set +a

env | sort

kubectl -n $NS_EPAS get svc 

echo "Patching EPAS 16 service to use NodePort..."
kubectl patch svc epas16-rw -n $NS_EPAS \
  -p '{"spec": {"type": "NodePort","ports":[{"port":5432,"targetPort":5432,"nodePort":30432}]}}'

kubectl -n $NS_EPAS get svc 

# K8s nodeport range is 30000-32767
