#!/bin/sh

PRIMARY=$1
echo "kubectl drain $PRIMARY --ignore-daemonsets --delete-emptydir-data"
kubectl drain $PRIMARY --ignore-daemonsets --delete-emptydir-data
