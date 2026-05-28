#!/bin/sh

kubectl -n edb port-forward svc/epas16-rw 5432:5432 &
PF_PID=$!
echo "Port-forwarding started with PID $PF_PID"
