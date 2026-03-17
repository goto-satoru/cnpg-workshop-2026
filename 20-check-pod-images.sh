#!/bin/bash

# Check container images for epas16 pods
pod_name="epas16"

for i in 1 2 3; do
  echo "    pod: $pod_name-$i"
  kubectl describe po $pod_name-$i | grep -E "[ ]+docker\.enterprisedb\.com/k8s/edb-postgres-advanced:"
done
