#!/bin/sh

echo "MinIO console:"
echo "https://localhost:9001"

echo "forward MinIO console to http://localhost:9001"
kubectl port-forward svc/minio-console 9001:9001
