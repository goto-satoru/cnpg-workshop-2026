#!/bin/sh

RECOVERY_TARGET_TIME="2026-02-22 12:00:00"

echo "Point-in-Time Recovery(PITR): Restoring to $RECOVERY_TARGET_TIME"

cat <<EOF | kubectl apply -f -
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Cluster
metadata:
  name: epas16-restored
  namespace: edb
spec:
  instances: 3
  imageName: docker.enterprisedb.com/k8s/edb-postgres-advanced:16.11
  imagePullSecrets:
  - name: edb-pull-secret
  storage:
    size: 1Gi

  # Recovery configuration from backup
  bootstrap:
    recovery:
      source: epas16
      backupID: "20260222T120000"
      recoveryTarget:
        targetXID: "recovery-target-immediate"  # Stop at backup completion
  
  # Backup configuration for the new cluster
  backup:
    retentionPolicy: "7d"
    barmanObjectStore:
      destinationPath: "s3://barman-restored"
      endpointURL: "http://minio.edb.svc.cluster.local:9000"
      s3Credentials:
        accessKeyId:
          name: backup-storage-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: backup-storage-creds
          key: SECRET_ACCESS_KEY
      wal:
        compression: gzip
        maxParallel: 2
EOF
