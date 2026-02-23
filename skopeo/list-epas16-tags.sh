#!/bin/sh -x

CS_USER="k8s"
CS_TOKEN=$EDB_SUBSCRIPTION_TOKEN

skopeo list-tags --creds=${CS_USER}:${CS_TOKEN} \
  docker://docker.enterprisedb.com/${CS_USER}/edb-postgres-advanced \
  | jq -r '.Tags[] | select(test("^16\\.[0-9]+"))'
  