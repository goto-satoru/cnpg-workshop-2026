#!/bin/sh

echo "forward silo port:"
echo "https://localhost:9000"

echo "forward Silo console to http://localhost:9000"
kubectl -n edb port-forward svc/silo 9000:9000

mc alias set local http://localhost:9000 silo_admin silo_passwd_1615

echo "List silo buckets and objects:"
echo "mc ls local/barman --recursive --summarize"

mc ls local/barman --recursive --summarize
