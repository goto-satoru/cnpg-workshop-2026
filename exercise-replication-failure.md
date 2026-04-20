



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
minio-6bc9dd99b4-lr4lj   1/1     Running   0          14m     10.244.1.3   my-k8s-worker2   <none>           <none>
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


the the primary pod is running on ``my-k8s-worker2`` node.

### drain ``my-k8s-worker2`` node, on which primary pod is runnung.


```
kubectl drain my-k8s-worker2 --ignore-daemonsets --delete-emptydir-data
```

### make some changes to EPAS16 cluster

```
k cnp psql epas16
psql (16.13.0)
Type "help" for help.

postgres=#
```



```
kubectl delete node my-k8s-worker
```

### recover my-k8s-worker3

```
kubectl uncordon my-k8s-worker3
```
