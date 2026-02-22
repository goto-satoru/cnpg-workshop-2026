#!/bin/sh

echo "Forwarding Grafana to http://localhost:3000 "
kubectl -n postgresql-operator-system port-forward svc/prometheus-grafana 3000:80
