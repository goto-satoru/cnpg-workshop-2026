



```
 k get cluster
NAME     AGE   INSTANCES   READY   STATUS                     PRIMARY
epas16   14m   3           3       Cluster in healthy state   epas16-2
```

```
kubectl get po -o wide
NAME                     READY   STATUS    RESTARTS   AGE     IP           NODE             NOMINATED NODE   READINESS GATES
epas16-1                 1/1     Running   0          4m43s   10.244.3.6   my-k8s-worker3   <none>           <none>
epas16-2                 1/1     Running   0          12m     10.244.2.5   my-k8s-worker    <none>           <none>
epas16-3                 1/1     Running   0          11m     10.244.1.6   my-k8s-worker2   <none>           <none>
```

or 

```
kubectl cnp status epas16
...
Instances status
Name      Current LSN  Replication role  Status  QoS         Manager Version  Node
----      -----------  ----------------  ------  ---         ---------------  ----
epas16-1  0/8000060    Primary           OK      BestEffort  1.28.2           my-k8s-worker2
epas16-2  0/8000060    Standby (async)   OK      BestEffort  1.28.2           my-k8s-worker
epas16-3  0/8000060    Standby (async)   OK      BestEffort  1.28.2           my-k8s-worker3
```


the Primary pod is running on ``my-k8s-worker2`` node.

### drain ``my-k8s-worker2`` node

```
kubectl drain my-k8s-worker2 --ignore-daemonsets --delete-emptydir-data
```

### ingest sample data to EPAS16 cluster

```
k cnp psql epas16
```
ingest 1,000,000 records to a sample table.

```sql
CREATE TABLE IF NOT EXISTS t1 (
	id SERIAL PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	description TEXT,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TEMP TABLE wal_baseline AS
SELECT pg_current_wal_lsn() AS start_lsn;

INSERT INTO t1 (name, description, created_at, updated_at)
SELECT
	'User ' || gs,
	'Sample record ' || gs,
	CURRENT_TIMESTAMP - (gs || ' seconds')::INTERVAL,
	CURRENT_TIMESTAMP - (gs || ' seconds')::INTERVAL
FROM generate_series(1, 1000000) AS gs;

SELECT COUNT(*) AS total_rows FROM t1;

SELECT
	start_lsn AS wal_lsn_before,
	pg_current_wal_lsn() AS wal_lsn_after,
	pg_wal_lsn_diff(pg_current_wal_lsn(), start_lsn) AS wal_bytes_generated,
	pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), start_lsn)) AS wal_size_generated
FROM wal_baseline;
```

### recover(uncordon) my-k8s-worker2

```
kubectl uncordon my-k8s-worker2
```

pod log 

```
kubectl logs epas16-1 -n edb -c postgres

{"level":"info","ts":"2026-04-20T03:45:40.188251348Z","logger":"postgres","msg":"record","logging_pod":"epas16-1","record":{"log_time":"2026-04-20 03:45:40.188 UTC","process_id":"2427","session_id":"69e5a164.97b","session_line_num":"2","session_start_time":"2026-04-20 03:45:40 UTC","transaction_id":"0","error_severity":"FATAL","sql_state_code":"08P01","message":"could not receive data from WAL stream: ERROR:  requested WAL segment 000000020000000000000009 has already been removed","backend_type":"walreceiver","query_id":"0"}}
```

pg_replication_slots

```
postgres=# SELECT slot_name, slot_type, active, restart_lsn, wal_status FROM pg_replication_slots;
   slot_name   | slot_type | active | restart_lsn | wal_status
---------------+-----------+--------+-------------+------------
 _cnp_epas16_3 | physical  | t      | 0/3299A5B8  | reserved
 _cnp_epas16_1 | physical  | f      |             | lost
(2 rows)
```

