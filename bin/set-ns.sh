#!/bin/sh

# namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')
# echo $namespaces
# choose NS
kubectl get ns
echo ""
read -p "Choose your namespace: " ns
kubectl config set-context --current --namespace $ns
