#!/bin/bash

# Check container images for pg16 pods
pod_name="pg16"

for i in 1 2 3; do
  echo "    pod: $pod_name-$i"
  kubectl -n edb describe po $pod_name-$i | grep " ghcr.io/cloudnative-pg/postgresql:"
done
