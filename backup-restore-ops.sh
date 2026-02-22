#!/bin/bash

# Common backup and restore operations for CNPG

NAMESPACE="default"
CLUSTER_NAME="example"

function show_help() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  backup-now                    - Create immediate backup"
    echo "  list-backups                  - List all backups"
    echo "  restore <backup-name>         - Restore from specific backup"
    echo "  restore-pitr <timestamp>      - Point-in-time restore (format: 'YYYY-MM-DD HH:MM:SS')"
    echo "  backup-status                 - Show backup status"
    echo "  cleanup-old-backups          - Remove old backups"
    echo "  export-backup <backup-name>   - Export backup to local file"
    echo ""
    echo "Examples:"
    echo "  $0 backup-now"
    echo "  $0 restore cluster-example-manual-backup"
    echo "  $0 restore-pitr '2024-08-05 14:30:00'"
    echo "  $0 list-backups"
}

function backup_now() {
    local backup_name="${CLUSTER_NAME}-manual-$(date +%Y%m%d-%H%M%S)"
    echo "Creating backup: $backup_name"
    
    cat <<EOF | kubectl apply -f -
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Backup
metadata:
  name: $backup_name
  namespace: $NAMESPACE
spec:
  cluster:
    name: $CLUSTER_NAME
EOF
    
    echo "Backup $backup_name created. Monitor with: kubectl get backup $backup_name -n $NAMESPACE -w"
}

function list_backups() {
    echo "All backups:"
    kubectl get backup -n $NAMESPACE
    echo ""
    echo "Scheduled backups:"
    kubectl get scheduledbackup -n $NAMESPACE
}

function restore_from_backup() {
    local backup_name=$1
    if [ -z "$backup_name" ]; then
        echo "Error: Backup name required"
        exit 1
    fi
    
    local restore_cluster_name="cluster-restored-$(date +%Y%m%d%H%M%S)"
    echo "Restoring from backup $backup_name to new cluster $restore_cluster_name"
    
    cat <<EOF | kubectl apply -f -
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Cluster
metadata:
  name: $restore_cluster_name
  namespace: $NAMESPACE
spec:
  instances: 3
  storage:
    size: 1Gi
  bootstrap:
    recovery:
      backup:
        name: $backup_name
EOF
    
    echo "Restore cluster $restore_cluster_name created. Monitor with: kubectl get cluster $restore_cluster_name -n $NAMESPACE -w"
}

function restore_pitr() {
    local target_time="$1"
    if [ -z "$target_time" ]; then
        echo "Error: Target time required (format: 'YYYY-MM-DD HH:MM:SS')"
        exit 1
    fi
    
    local restore_cluster_name="cluster-pitr-$(date +%Y%m%d%H%M%S)"
    echo "Restoring to point-in-time: $target_time"
    echo "New cluster name: $restore_cluster_name"
    
    cat <<EOF | kubectl apply -f -
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Cluster
metadata:
  name: $restore_cluster_name
  namespace: $NAMESPACE
spec:
  instances: 3
  storage:
    size: 1Gi
  bootstrap:
    recovery:
      source: cluster-backup-source
      recoveryTarget:
        targetTime: "$target_time"
  externalClusters:
    - name: cluster-backup-source
      barmanObjectStore:
        destinationPath: "s3://cnpg-backup-bucket/cluster-example"
        s3Credentials:
          accessKeyId:
            name: backup-storage-creds
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: backup-storage-creds
            key: SECRET_ACCESS_KEY
        endpointURL: "http://minio.default.svc.cluster.local:9000"
EOF
    
    echo "Point-in-time restore cluster $restore_cluster_name created."
}

function backup_status() {
    echo "=== Cluster Status ==="
    kubectl get cluster $CLUSTER_NAME -n $NAMESPACE -o custom-columns=\
"NAME:.metadata.name,STATUS:.status.phase,INSTANCES:.spec.instances,READY:.status.readyInstances"
    
    echo ""
    echo "=== Backup Status ==="
    kubectl get backup -n $NAMESPACE -o custom-columns=\
"NAME:.metadata.name,CLUSTER:.spec.cluster.name,PHASE:.status.phase,STARTED:.status.startedAt,COMPLETED:.status.stoppedAt"
    
    echo ""
    echo "=== Scheduled Backup Status ==="
    kubectl get scheduledbackup -n $NAMESPACE -o custom-columns=\
"NAME:.metadata.name,SCHEDULE:.spec.schedule,SUSPENDED:.spec.suspend,LAST-BACKUP:.status.lastCheckTime"
}

function cleanup_old_backups() {
    echo "Cleaning up backups older than 30 days..."
    kubectl get backup -n $NAMESPACE -o json | \
    jq -r '.items[] | select((.status.stoppedAt | fromdateiso8601) < (now - 30*24*3600)) | .metadata.name' | \
    xargs -I {} kubectl delete backup {} -n $NAMESPACE
    echo "Cleanup complete."
}

function export_backup() {
    local backup_name=$1
    if [ -z "$backup_name" ]; then
        echo "Error: Backup name required"
        exit 1
    fi
    
    echo "Exporting backup $backup_name..."
    echo "Note: This requires access to the backup storage directly."
    echo "For MinIO, you can use: mc cp --recursive local/cnpg-backup-bucket/cluster-example ./exported-backup/"
}

# Main script logic
case "$1" in
    backup-now)
        backup_now
        ;;
    list-backups)
        list_backups
        ;;
    restore)
        restore_from_backup "$2"
        ;;
    restore-pitr)
        restore_pitr "$2"
        ;;
    backup-status)
        backup_status
        ;;
    cleanup-old-backups)
        cleanup_old_backups
        ;;
    export-backup)
        export_backup "$2"
        ;;
    *)
        show_help
        exit 1
        ;;
esac
