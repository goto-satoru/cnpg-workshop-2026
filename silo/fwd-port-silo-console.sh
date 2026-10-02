#!/bin/sh

echo "forward Silo console to http://localhost:9001"
kubectl -n edb port-forward svc/silo-minio-console 9001:9001
