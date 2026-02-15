#!/bin/sh

CLUSTER_NAME="my-k8s"

echo "Creating a kind cluster $CLUSTER_NAME ..."
kind create cluster --config kind/kind-config.yaml --name $CLUSTER_NAME
