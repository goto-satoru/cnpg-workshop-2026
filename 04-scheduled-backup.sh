#!/bin/bash

# Apply scheduled backup configuration for EPAS cluster
echo "Creating scheduled backup for epas16 cluster..."
kubectl apply -f cluster-bak-scheduled.yaml

# Check the scheduled backup status
echo ""
echo "Scheduled backup status:"
kubectl get scheduledbackup -n edb

echo ""
echo "To view backup history:"
echo "  kubectl get backup -n edb"
