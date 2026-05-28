#!/bin/sh

echo "forward MinIO port:"
echo "https://localhost:9000"

echo "forward MinIO console to http://localhost:9000"
kubectl -n edb port-forward svc/minio 9000:9000

mc alias set local http://localhost:9000 minio_admin minio_passwd_1614

echo "List MinIO buckets and objects:"
echo "mc ls local/barman --recursive --summarize"

mc ls local/barman --recursive --summarize

