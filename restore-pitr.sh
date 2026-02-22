#!/bin/sh

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
  bootstrap:
    recovery:
      source: epas16  # Original cluster name
      recoveryTarget:
        # Restore to this point in time
        targetTime: "2026-02-22 10:30:00" 
        # Or use: targetTimeline: latest
        # Or use: targetXID: 1000

  # Backup configuration for the new cluster
  backup:
    retentionPolicy: "7d"
    barmanObjectStore:
      destinationPath: "s3://barman"
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
