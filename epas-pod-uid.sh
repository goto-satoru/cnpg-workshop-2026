#!/bin/sh

oc get pods -l k8s.enterprisedb.io/cluster=epas16 -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.uid}{"\n"}{end}'
