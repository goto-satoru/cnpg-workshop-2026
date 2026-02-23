# EDB CloudNativePG Cluster Hands-On

Install CloudNativePG Cluster and deploy EPAS 16 database with Barman Object Store backup capability using KIND (Kubernetes in Docker).


## Overview

- Create KIND cluster (1 control plane + 3 worker nodes)
- Install CloudNativePG Cluster operator
- Deploy EPAS 16 cluster (3-instance configuration)
- Configure Barman Object Store backup using MinIO
- Execute scheduled and manual backups
- Perform recovery using backups on MinIO


### Helper Scripts
- `0-create-kind-cluster.sh` - Create KIND cluster (uses `kind/kind-config.yaml`)
- `1-install-cnpg-c.sh` - Install CloudNative PostgreSQL operator (uses `.env` settings)
- `2-deploy-epas16.sh` - Deploy EPAS 16 database (uses `cluster-barman.yaml`, includes NodePort patch)
- `3-patch-epas-svc.sh` - Change EPAS service to NodePort (port 30432)

### Backup Related
- `4-apply-scheduled-backup.sh` - Apply scheduled backup
- `5-backup.sh` - Execute manual backup with timestamp
- `scheduled-backup.yaml` - Scheduled backup manifest (6-field cron format, runs every 3 minutes)
- `cluster-barman.yaml` - Cluster configuration using Barman Object Store (MinIO) (3 instances, 7-day retention)

### Cleanup Scripts
- `8-del-cnpg-c.sh` - Delete CNPG operator and namespace
- `9-del-kind.sh` - Delete entire KIND cluster

### Manifests
- `cluster.yaml` - Basic cluster manifest (no backup, 3 instances, 1Gi storage)
- `cluster-barman.yaml` - Cluster manifest with Barman backup (recommended)
- `scheduled-backup.yaml` - Scheduled backup definition (ScheduledBackup resource)
- `kind/kind-config.yaml` - KIND cluster configuration (port mapping, 4-node setup)

### Configuration Files
- `dotenv-sample` - Sample environment variables (copy to `.env` for use)


### Utility Scripts
- `bin/set-ns.sh` - Change current default namespace. Recommended to set to `edb` when performing continuous operations on EPAS cluster
- `bin/decode-yaml.sh` - Decode Base64 encoded values in YAML using yq
- `fwd-port-minio-console.sh` - Port forwarding to MinIO console (http://localhost:9001)
- `list-cnpg-tags.sh` - List CNPG image tags (uses skopeo)
- `list-epas-tags.sh` - List EPAS image tags
- `list-epas16-tags.sh` - List EPAS 16 image tags (version 16.x)

### Sample SQL
- `ddl-dml/create-table-t1.sql` - Create sample table t1 with data insertion

### MinIO Installation
- `kind/install-minio.sh` - Install MinIO using Helm (standalone mode, 5Gi storage)


## Prerequisites

### Required Tools
- **Docker** - Container runtime
- **[kind](https://kind.sigs.k8s.io/)** - Kubernetes in Docker
- **[kubectl](https://kubernetes.io/docs/tasks/tools/)** - Kubernetes CLI
- **[kubectl CNPG plugin](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/kubectl-plugin/)** - For CloudNativePG management
- **[skopeo](https://github.com/containers/skopeo/blob/main/install.md)** - For container image inspection and tag listing
- **[Helm](https://helm.sh/)** - For MinIO installation (if using backup feature)
- **[yq](https://github.com/mikefarah/yq)** - For YAML processing (used for secret decoding)


### EDB Subscription
- **EDB_SUBSCRIPTION_TOKEN** - Required for authentication to EDB container registry (docker.enterprisedb.com)
- Copy `dotenv-sample` to `.env` and set your token


## Environment Configuration

### 1. Prepare Environment Variable File

```bash
cp dotenv-sample .env
```

Set the following in the `.env` file:

```bash
NS_OPERATOR=postgresql-operator-system
NS_EPAS=edb
SECRET_NAME=edb-pull-secret
CNPG_VERSION=1.28.1

CLOUDSMITH=docker.enterprisedb.com
CS_USER=k8s

MINIO_ROOT_USER=minio_admin
MINIO_ROOT_PASSWORD=your_minio_password
```


## Quick Start

### Create KIND Cluster

```bash
./0-create-kind-cluster.sh
```

**Created Configuration:**
- Cluster Name: `my-k8s`
- Nodes: 1 control plane + 3 workers
- Kubernetes Version: v1.33.7
- kubeProxyMode: ipvs

**Port Mappings:**
- Host `5432` → Container `30432` (PostgreSQL primary service)
- Host `5444` → Container `30444` (PostgreSQL secondary service)
- Host `9000` → Container `39000` (MinIO API)
- Host `9001` → Container `39001` (MinIO console)

### Install MinIO (for Barman Cloud)

```bash
./kind/install-minio.sh
```

**MinIO Configuration:**
- Namespace: `edb`
- Mode: standalone (single instance)
- Admin User: `minio_admin`
- Storage: 5Gi (PersistentVolume)
- Service Type: ClusterIP

### Install CNPG Operator

```bash
./1-install-cnpg-c.sh
```

**Execution Steps:**
1. Create namespaces: `postgresql-operator-system` and `edb`
2. Create Docker registry secret: `edb-pull-secret` (for fetching EDB container images)
3. Deploy CNPG operator (version 1.28.1)
4. Verify operator startup (timeout: 300 seconds)

Verification command:
```bash
kubectl get pods -n postgresql-operator-system
```

### Deploy EPAS16 Cluster

```bash
./2-deploy-epas16.sh
```

**Deployed Components:**
- **Cluster Name:** `epas16`
- **Namespace:** `edb`
- **Instances:** 3 (1 primary + 2 standby)
- **Image:** `docker.enterprisedb.com/k8s/edb-postgres-advanced:16.11`
- **Storage:** 1Gi per instance
- **Backup Configuration:**
  - Backup destination: MinIO (`s3://epas16-backups`)
  - Retention period: 7 days
  - WAL compression: gzip
  - Parallel processing: 2

**Created Services:**
- `epas16-rw` (read-write) - NodePort 30432 (connection to primary)
- `epas16-ro` (read-only) - ClusterIP (read-only connection)  
- `epas16-r` (replica) - ClusterIP (replica connection)

The script automatically executes:
1. Apply `cluster-barman.yaml`
2. Create backup secret
3. Wait 60 seconds
4. Verify deployment ready (timeout: 600 seconds)
5. Change `epas16-rw` service to NodePort

### Get EPAS16 Cluster Status using kubectl cnp

```bash
kubectl -n edb cnp status epas16 -n edb

k -n edb cnp status epas16 -n edb

watch -n 5 kubectl -n edb cnp status epas16 -n edb
```

### Verify EPAS16 Cluster Services

```bash
kubectl -n edb get svc
```

Example output:
```
NAME        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
epas16-r    ClusterIP   10.96.127.18    <none>        5432/TCP         5m
epas16-ro   ClusterIP   10.96.234.24    <none>        5432/TCP         5m
epas16-rw   NodePort    10.96.111.202   <none>        5432:30432/TCP   5m
minio       ClusterIP   10.96.200.100   <none>        9000/TCP         10m
minio-console ClusterIP 10.96.50.50    <none>        9001/TCP         10m
```


## Connect to EPAS

### Using cnp Plugin

```bash
k cnp status epas16 -n edb
```

### Get Application User Password

```bash
kubectl -n edb get secret epas16-app -o yaml | ./bin/decode-yaml.sh | grep password:
```

Example output:
```yaml
password: your_generated_password
```

### Connect from KIND Host

```bash
psql "postgresql://app:<password>@localhost:5432/app"
```

### Connect from Remote Host (local PC)

```bash
psql "postgresql://app:<password>@<kind_host_ip>:5432/app"
```

`<kind_host_ip>` is the public IP address of the host running KIND.

### Connection Endpoints

- **Read-Write (Primary):** `epas16-rw:5432` - All operations supported
- **Read-Only:** `epas16-ro:5432` - SELECT queries distributed across multiple replicas
- **Specific Replica:** `epas16-r:5432` - Direct connection to replica


## Create Sample Table

```bash
psql -h localhost -U app -d app -f ddl-dml/create-table-t1.sql
```

**Created contents:**
- Table name: `t1`
- Columns: `id` (SERIAL), `name` (VARCHAR), `description` (TEXT), `created_at`, `updated_at`
- 3 rows of sample data are inserted

Verification command:
```sql
SELECT * FROM t1;
```


## Backup and Recovery

### Backup Architecture

Backup configuration set in `cluster-barman.yaml`:
- **Backup Tool:** Barman (Backup and Recovery Manager)
- **Storage:** MinIO (S3-compatible object storage)
- **Bucket:** `s3://epas16-backups`
- **Retention Period:** 7 days (`retentionPolicy: "7d"`)
- **WAL Archive:** gzip compression, parallel degree 2
- **Credentials:** Secret `backup-storage-creds`

### Configure Scheduled Backup

```bash
./4-apply-scheduled-backup.sh
```

**`scheduled-backup.yaml` Configuration:**
- **Resource Name:** `epas16-scheduled`
- **Schedule:** `"0 */3 * * * *"` - Run every 3 minutes
- **Cron Format:** 6 fields (`seconds minutes hours day month weekday`)
  - Example: `"0 0 2 * * *"` = Every day at 2:00:00 AM
  - Example: `"0 */10 * * * *"` = Every 10 minutes (at 0 seconds)
  - Example: `"0 */3 * * * *"` = Every 3 minutes (at 0 seconds - default)
- **immediate:** `true` - Execute backup immediately upon resource creation
- **suspend:** `false` - Enable scheduled backup
- **method:** `barmanObjectStore` - Backup to MinIO

**Note:** CloudNativePG schedule uses 6-field format (includes seconds). This differs from standard 5-field cron.

### Execute Manual Backup

```bash
./5-backup.sh
```

A backup is created with timestamp (example: `backup-epas16-0222-1530`).

### Verify Backups

```bash
# Check scheduled backups
kubectl get scheduledbackup -n edb

# Check backup history
kubectl get backup -n edb

# Check backup details
kubectl describe backup <backup-name> -n edb
```

### Verify Backups in MinIO

Access MinIO console to verify backups:

```bash
./fwd-port-minio-console.sh
```

Access http://localhost:9001 in browser:
- **Username:** `minio_admin`
- **Password:** `xxxxxxxxxxxxxx`
- **Bucket:** `barman`


## Grafana Dashboard

- Template: https://github.com/cloudnative-pg/grafana-dashboards/blob/main/charts/cluster/grafana-dashboard.json




## Cleanup

### Option 1: Delete CNPG Resources Only

```bash
./8-del-cnpg-c.sh
```

**Deleted items:**
- CNPG operator (`postgresql-operator-system` namespace)
- EPAS cluster (`edb` namespace)
- All related resources (Pods, Services, PVCs, Secrets)

KIND cluster itself remains. You can rerun from `./1-install-cnpg-c.sh`.

### Option 2: Delete Entire KIND Cluster

```bash
./9-del-kind.sh
```

**Deleted items:**
- Entire KIND cluster `my-k8s`
- All nodes (control plane + 3 workers)
- All data, backups, and configuration

**WARNING:** This operation is irreversible. All data will be lost.

## Tips and Operational Commands

### Check Cluster Status

```bash
# Cluster overview
kubectl get cluster -n edb

# Pod status
kubectl get pods -n edb

# Detailed status using CNPG plugin
kubectl cnpg status epas16 -n edb

# Cluster details
kubectl describe cluster epas16 -n edb
```

### Check Logs

```bash
# Primary Pod logs
kubectl logs -n edb epas16-1 -f

# Operator logs
kubectl logs -n postgresql-operator-system deployment/postgresql-operator-controller-manager -f
```

### Access MinIO Console

To access the backup storage (MinIO) console:

```bash
./fwd-port-minio-console.sh
```

Then access http://localhost:9001 in browser.
- **Username:** `minio_admin`
- **Password:** `minio_admin_0227`

### Check Available Image Tags

To check available Docker image tags for CNPG or EPAS:

```bash
# CNPG operator version list (example: 1.28.1)
./list-cnpg-tags.sh

# EPAS all version tags (10.x, 11.x, 12.x, 13.x, 14.x, 15.x, 16.x)
./list-epas-tags.sh

# EPAS 16.x tags (example: 16.11)
./list-epas16-tags.sh
```

**Note:** These scripts require `skopeo` and environment variable `EDB_SUBSCRIPTION_TOKEN`.

### Check Host Port Mappings

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

Expected output:
```
NAMES                  PORTS
my-k8s-control-plane   0.0.0.0:6443->6443/tcp, 0.0.0.0:5432->30432/tcp, 0.0.0.0:5444->30444/tcp, 0.0.0.0:9000->39000/tcp, 0.0.0.0:9001->39001/tcp
my-k8s-worker          
my-k8s-worker2         
my-k8s-worker3         
``` 

### Get KIND kubeconfig and Remote Access

#### Get kubeconfig

To obtain kubeconfig for KIND cluster and use with kubectl:

```bash
kind get kubeconfig --name my-k8s > kubeconfig.yaml
export KUBECONFIG=kubeconfig.yaml
kubectl cluster-info
```

This outputs cluster configuration to `kubeconfig.yaml`, which becomes active in that shell session.

#### Access KIND Cluster from Remote Host

To connect from remote local PC to KIND cluster, modify kubeconfig:

**Before:**
```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTi...
    server: https://0.0.0.0:6443
  name: kind-my-k8s
contexts:
- context:
    cluster: kind-my-k8s
    user: kind-my-k8s
  name: kind-my-k8s
current-context: kind-my-k8s
kind: Config
preferences: {}
users:
- name: kind-my-k8s
  user:
    client-certificate-data: LS0tLS1CRUdJTi...
    client-key-data: LS0tLS1CRUdJTi...
```

**After:**
```yaml
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true  # Skip certificate verification (test environment only)
    server: https://192.168.1.100:6443  # Change to actual IP address of KIND host
  name: kind-my-k8s
contexts:
- context:
    cluster: kind-my-k8s
    user: kind-my-k8s
  name: kind-my-k8s
current-context: kind-my-k8s
kind: Config
preferences: {}
users:
- name: kind-my-k8s
  user:
    client-certificate-data: LS0tLS1CRUdJTi...
    client-key-data: LS0tLS1CRUdJTi...
```

**Changes:**
1. Change `certificate-authority-data` to `insecure-skip-tls-verify: true`
2. Change `server` from `0.0.0.0` to actual IP address of KIND host

**WARNING:** Do not use `insecure-skip-tls-verify: true` in production. This is test environment only.

Now you can run kubectl commands from local PC:

```bash
export KUBECONFIG=/path/to/kubeconfig.yaml
kubectl get nodes
kubectl get pods -n edb
```


## Troubleshooting

### Pod fails to start

```bash
# Check Pod status
kubectl get pods -n edb

# Pod details
kubectl describe pod <pod-name> -n edb

# Check events
kubectl get events -n edb --sort-by='.lastTimestamp'
```

### Image pull failure

```bash
# Check secret
kubectl get secret edb-pull-secret -n edb

# Secret details
kubectl describe secret edb-pull-secret -n edb

# Verify EDB_SUBSCRIPTION_TOKEN is correctly set
echo $EDB_SUBSCRIPTION_TOKEN
```

### Backup failure

```bash
# Check backup status
kubectl get backup -n edb

# Backup details
kubectl describe backup <backup-name> -n edb

# Check MinIO Pod status
kubectl get pods -n edb | grep minio

# Check MinIO logs
kubectl logs -n edb <minio-pod-name>
```

### Cannot connect to database

```bash
# Check services
kubectl get svc -n edb

# Check NodePort
kubectl get svc epas16-rw -n edb -o jsonpath='{.spec.ports[0].nodePort}'

# Try direct connection via port-forward
kubectl port-forward -n edb svc/epas16-rw 5432:5432
```


## Technical Specifications

### Cluster Configuration
- **PostgreSQL Version:** EDB Postgres Advanced Server 16.11
- **Instances:** 3 (1 primary + 2 standby)
- **Replication:** Streaming replication (synchronous/asynchronous)
- **Storage:** 1Gi per instance (PersistentVolume)
- **High Availability:** Automatic failover (managed by CNPG operator)

### Backup Configuration
- **Backup Tool:** Barman 2.x
- **Storage Backend:** MinIO (S3-compatible)
- **Backup Type:** Full backup + WAL archive
- **Retention Period:** 7 days
- **Compression:** gzip
- **Parallel Processing:** 2 streams

### Network
- **CNI:** KIND default (kindnet)
- **kube-proxy Mode:** IPVS
- **Service Types:** ClusterIP + NodePort


## References

### Official Documentation
- [EDB Postgres for Kubernetes - Installation and Upgrade](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/installation_upgrade/)
- [EDB Postgres for Kubernetes - Backup and Recovery](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/backup_recovery/)
- [CloudNativePG - Scheduled Backups](https://cloudnative-pg.io/documentation/current/backup/)
- [KIND - Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)

### Community
- [CloudNativePG GitHub](https://github.com/cloudnative-pg/cloudnative-pg)
- [EDB Community](https://www.enterprisedb.com/community)

