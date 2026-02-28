#!/bin/sh

if [ $# -eq 0 ]; then
    PORT=30080
else
    PORT=$1
fi

echo "Forwarding Grafana to http://localhost:$PORT "
kubectl -n postgresql-operator-system port-forward svc/prometheus-grafana $PORT:80
