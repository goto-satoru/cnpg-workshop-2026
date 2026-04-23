#!/bin/sh

NODE=$1
echo "kubectl uncordon $NODE"
kubectl uncordon $NODE
