#!/bin/sh

if [ $# -eq 0 ]; then
    PORT=9090
else
    PORT=$1
fi

echo "Forwarding Prometheus to http://localhost:$PORT "
kubectl -n postgresql-operator-system port-forward svc/prometheus-kube-prometheus-prometheus $PORT:$PORT
