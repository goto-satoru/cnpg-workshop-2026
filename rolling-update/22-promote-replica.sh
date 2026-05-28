#!/bin/bash
# https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/rolling_update/

echo "Promoting replica to primary..."
kubectl cnp promote epas16 epas16-2 -n edb 
