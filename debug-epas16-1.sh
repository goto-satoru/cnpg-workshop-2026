#!/bin/bash

echo "=== Pod Status ==="
kubectl get po -n edb epas16-1

echo -e "\n=== Pod Events ==="
kubectl describe po epas16-1 -n edb | grep -A 20 "Events:"

echo -e "\n=== Pod Logs (last 50 lines) ==="
kubectl logs -n edb epas16-1 -c postgres --tail=50

echo -e "\n=== Cluster Status ==="
kubectl cnp status epas16 -n edb
