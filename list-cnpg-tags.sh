#!/bin/sh

CS_USER="k8s"
CS_TOKEN=$EDB_SUBSCRIPTION_TOKEN
CS_REPO="edb-postgres-for-cloudnativepg"

echo "listing ${CS_REPO} images:"
skopeo list-tags --creds=$CS_USER:$EDB_SUBSCRIPTION_TOKEN \
  docker://docker.enterprisedb.com/${CS_USER}/${CS_REPO} \
  | jq -r '.Tags[] | select(test("^1\\.[0-9]+\\.[0-9]$"))'
