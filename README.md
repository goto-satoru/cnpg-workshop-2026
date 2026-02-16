
# EDB CloudNativePG Cluster 演習

KIND(Kubernetes in Docker)を使用して CloudNativePG クラスターを構築，EPAS 16データベースをデプロイします。


## プロジェクト構成

- `0-create-kind-cluster.sh` - KINDクラスターの作成
- `1-install-cnpg-c.sh` - CloudNative PostgreSQLオペレーターのインストール
- `2-deploy-epas16.sh` - EPAS 16データベースのデプロイ
- `8-delete-cnpg-c.sh` - CNPGリソースの削除
- `9-del-kind.sh` - KINDクラスターの削除
- `cluster.yaml` - クラスターのマニフェスト
- `kind/kind-config.yaml` - ポートマッピング付きKINDクラスター設定
- `create-table-t1.sql` - テーブルt1作成用のサンプルDDL/DML


## 前提条件

- Docker
- [kind](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [kubectl CNPG Cluster プラグイン](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/kubectl-plugin/)
- [skopeo](https://github.com/containers/skopeo/blob/main/install.md)


## クイックスタート

### 1. KINDクラスター作成

```bash
./0-create-kind-cluster.sh
```

以下のポートマッピングを持つKINDクラスターが作成されます：
- コンテナポート 5432 → ホストポート 30432（プライマリデータベース）
- コンテナポート 5444 → ホストポート 30444（セカンダリサービス）

### 2. CNPG Cluster オペレーターのインストール

```bash
./1-install-cnpg-c.sh
```


### 3. EPAS 16 のデプロイ

```bash
./2-deploy-epas16.sh
```

このコマンドで、EPAS 16が3つのサービスとともにデプロイされます：
- `epas16-rw`（読み書き）- NodePortサービス
- `epas16-ro`（リードオンリー）- ClusterIPサービス
- `epas16-r`（レプリカ）- ClusterIPサービス


## EPAS への接続

### kindホスト上での接続

EPASクラスター のパスワードは以下で取得できます：

```bash
kubectl -n edb get secret epas16-app -oyaml | ./bin/decode-yaml.sh | grep password:
```

```
$ psql postgresql://app:<app_user_passwd>@localhost:5432/app
```

### ローカルホスト（あなたのPC）からの接続

```
psql postgresql://app:<app_user_passwd>@<public_ip_kind_host>:5432/app
```


## サービス情報

稼働中のサービスを確認するには：

```bash
kubectl -n edb get svc
```

期待される出力例：

```
NAME        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
epas16-r    ClusterIP   10.96.127.18    <none>        5432/TCP         38m
epas16-ro   ClusterIP   10.96.234.24    <none>        5432/TCP         38m
epas16-rw   NodePort    10.96.111.202   <none>        5432:30432/TCP   38m
```


## サンプルテーブルの作成

```bash
psql -h localhost -U app -d app -f create-table-t1.sql
```

上記で取得した app_user_passwd が必要です。


## クリーンアップ


```bash
# KINDクラスターの削除
./9-del-kind.sh
```

## tips

### ホストポートの確認

```
$ docker ps --format "table {{.Names}}\t{{.Ports}}"
NAMES                  PORTS
my-k8s-control-plane   0.0.0.0:6443->6443/tcp, 0.0.0.0:5432->30432/tcp, 0.0.0.0:5444->30444/tcp
my-k8s-worker
my-k8s-worker2
my-k8s-worker3
```

### 

### KIND の kubeconfig 取得方法

KIND クラスターの kubeconfig を取得し、kubectl で利用するには以下のコマンドを実行します：

```bash
kind get kubeconfig --name my-k8s > kubeconfig.yaml
export KUBECONFIG=kubeconfig.yaml
kubectl cluster-info
```
- これで kubeconfig が kubeconfig.yaml に出力され、そのセッションで有効になります。
- クラスター名が異なる場合は `my-k8s` を適宜置き換えてください。

### kubeconfig.yaml をリモートホストから利用するための修正

修正前
```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: 認証データ
    server: https://0.0.0.0:6443
  name: kind-my-k8s
```

修正後
```yaml
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://3.113.11.127:6443
  name: kind-my-k8s
```

ローカルホスト(ラップトップ等)で kubectl が利用できます(テスト環境以外では推奨されません)。


## 参考文献

- [EDB CloudNativePG ClusterPostgres - インストールとアップグレード](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/installation_upgrade/)

