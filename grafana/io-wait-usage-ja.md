# EPAS I/O Wait 監視の利用手順

このドキュメントは、次の 2 ファイルを使って EPAS/CNPG の I/O Wait を可視化する手順をまとめたものです。

- [epas_io_wait_queries.yaml](epas_io_wait_queries.yaml)
- [dashboard-io-wait.json](dashboard-io-wait.json)

## 1. 何をするためのファイルか

- [epas_io_wait_queries.yaml](epas_io_wait_queries.yaml)
  - EDB CNPG Cluster の customQueries 用 ConfigMap 定義です。
  - `pg_stat_activity` から wait event を集計し、Prometheus メトリクスとして公開します。
- [dashboard-io-wait.json](dashboard-io-wait.json)
  - 上記メトリクスを含む I/O Wait 可視化用の Grafana ダッシュボードです。

## 2. 前提条件

- 対象 Cluster が `edb` namespace に存在する
- Prometheus + Grafana が稼働している
- Cluster の `spec.monitoring` が有効化されている

## 3. custom query ConfigMap を適用

次を実行します。

```bash
kubectl apply -f epas_io_wait_queries.yaml -n edb
```

適用後、ConfigMap が作成されていることを確認します。

```bash
kubectl get configmap epas16-custom-queries -n edb
```

## 4. Cluster に customQueriesConfigMap を紐付け

Cluster マニフェストに次を設定します。

```yaml
spec:
  monitoring:
    enablePodMonitor: true
    customQueriesConfigMap:
      - name: epas16-custom-queries
        key: custom-queries.yaml
```

## 5. Grafana にダッシュボードをインポート

1. Grafana の Dashboards で Import を開く
2. [dashboard-io-wait.json](dashboard-io-wait.json) をアップロード
3. `DS_PROMETHEUS` で利用する Prometheus データソースを選択
4. Import を実行

## 6. ダッシュボードの変数を選択

インポート後、上部変数を次の順で選択します。

1. `DS_PROMETHEUS`
2. `namespace`
3. `pod`
4. 必要に応じて `node`

## 7. 動作確認

### 7.1 Prometheus でメトリクス確認

次のようなクエリで値が返ることを確認します。

```promql
sum by (pod, wait_event) (cnp_pg_stat_activity_wait_events_count{namespace="edb"})
```

### 7.2 Grafana で可視化確認

- `IO Wait Event 別バックエンド数`
- `Wait Event Type別バックエンド数 (全体)`

上記パネルにデータが表示されれば有効化できています。

## 8. よくあるハマりどころ

- `No data` になる
  - Cluster の `customQueriesConfigMap` の `name`/`key` が ConfigMap 側と一致しているか確認
  - `enablePodMonitor: true` が有効か確認
  - Prometheus の target が `up` か確認
- 変数が選べない
  - `DS_PROMETHEUS` が正しいデータソースを向いているか確認
  - `namespace`/`pod` に該当メトリクスが存在するか確認

## 9. 補足

- `customQueriesConfigMap` が参照するのは、ローカルファイル名ではなく ConfigMap の `data` キーです。
- そのため、ファイル名が `epas_io_wait_queries.yaml` でも、Cluster 側の `key` は `custom-queries.yaml` で問題ありません。
