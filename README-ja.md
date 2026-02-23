
# EDB CloudNativePG Cluster 演習

KIND (Kubernetes in Docker) を使用して CloudNativePG Cluster をインストール，EPAS 16 DBを Barman Object Store バックアップ機能付きでデプロイします。


## 概要

- KIND クラスター（1コントロールプレーン + 3ワーカーノード）の作成
- CloudNativePG Cluster オペレーターのインストール
- EPAS 16 クラスター（3インスタンス構成）のデプロイ
- MinIO を使用した Barman Object Store バックアップの設定
- スケジュールバックアップと手動バックアップの実行
- MinIO 上のバックアップを用いたリカバリ


### ヘルパー スクリプト
- `0-create-kind-cluster.sh` - KIND クラスターの作成（`kind/kind-config.yaml` を使用）
- `1-install-cnpg-c.sh` - CloudNative PostgreSQL オペレーターのインストール（`.env` 設定を使用）
- `2-deploy-epas16.sh` - EPAS 16 データベースのデプロイ（`cluster-barman.yaml` 使用、NodePort パッチ含む）
- `3-patch-epas-svc.sh` - EPAS サービスを NodePort に変更（ポート 30432）

### バックアップ関連
- `4-apply-scheduled-backup.sh` - スケジュールバックアップの適用
- `5-backup.sh` - タイムスタンプ付き手動バックアップの実行
- `scheduled-backup.yaml` - スケジュールバックアップのマニフェスト（6フィールド cron 形式、3分ごと実行）
- `cluster-barman.yaml` - Barman Object Store（MinIO）を使用したクラスター設定（3インスタンス、7日間保持）

### クリーンアップスクリプト
- `8-del-cnpg-c.sh` - CNPG オペレーターと名前空間の削除
- `9-del-kind.sh` - KIND クラスター全体の削除

### マニフェスト
- `cluster.yaml` - 基本クラスターマニフェスト（バックアップなし、3インスタンス、1Gi ストレージ）
- `cluster-barman.yaml` - Barman バックアップ機能付きクラスターマニフェスト（推奨）
- `scheduled-backup.yaml` - スケジュールバックアップ定義（ScheduledBackup リソース）
- `kind/kind-config.yaml` - KIND クラスター設定（ポートマッピング、4ノード構成）

### 設定ファイル
- `dotenv-sample` - 環境変数のサンプル（`.env` にコピーして使用）


### ユーティリティスクリプト
- `bin/set-ns.sh` - 現在のデフォルト名前空間を変更します。EPASクラスタに対する操作を連続して行う場合は，`edb` に設定することを推奨
- `bin/decode-yaml.sh` - YAML 内の Base64 エンコードされた値を yq でデコード
- `fwd-port-minio-console.sh` - MinIO コンソールへのポートフォワーディング（http://localhost:9001）
- `list-cnpg-tags.sh` - CNPG イメージタグのリスト表示（skopeo 使用）
- `list-epas-tags.sh` - EPAS イメージタグのリスト表示
- `list-epas16-tags.sh` - EPAS 16 イメージタグのリスト表示（バージョン 16.x）

### サンプル SQL
- `ddl-dml/create-table-t1.sql` - サンプルテーブル t1 の作成とデータ挿入

### MinIO インストール
- `kind/install-minio.sh` - Helm を使用した MinIO のインストール（スタンドアロンモード、5Gi ストレージ）


## 前提条件

### 必須ツール
- **Docker** - コンテナランタイム
- **[kind](https://kind.sigs.k8s.io/)** - Kubernetes in Docker
- **[kubectl](https://kubernetes.io/docs/tasks/tools/)** - Kubernetes CLI
- **[kubectl CNPG プラグイン](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/kubectl-plugin/)** - CloudNativePG 管理用
- **[skopeo](https://github.com/containers/skopeo/blob/main/install.md)** - コンテナイメージの検査とタグ一覧取得用
- **[Helm](https://helm.sh/)** - MinIO インストール用（バックアップ機能を使用する場合）
- **[yq](https://github.com/mikefarah/yq)** - YAML 処理用（シークレットのデコードに使用）


### EDB サブスクリプション
- **EDB_SUBSCRIPTION_TOKEN** - EDB のコンテナレジストリ（docker.enterprisedb.com）への認証に必要
- `dotenv-sample` を `.env` にコピーし、トークンを設定してください


## 環境設定

### 1. 環境変数ファイルの準備

```bash
cp dotenv-sample .env
```

`.env` ファイルに以下を設定：

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


## クイックスタート

### KIND クラスターの作成

```bash
./0-create-kind-cluster.sh
```

**作成される構成：**
- クラスター名: `my-k8s`
- ノード: 1 コントロールプレーン + 3 ワーカー
- Kubernetes バージョン: v1.33.7
- kubeProxyMode: ipvs

**ポートマッピング：**
- ホスト `5432` → コンテナ `30432` (PostgreSQL プライマリサービス)
- ホスト `5444` → コンテナ `30444` (PostgreSQL セカンダリサービス)
- ホスト `9000` → コンテナ `39000` (MinIO API)
- ホスト `9001` → コンテナ `39001` (MinIO コンソール)

### MinIO のインストール（Barman Cloud用）

```bash
./kind/install-minio.sh
```

**MinIO 設定：**
- ネームスペース: `edb`
- モード: standalone（単一インスタンス）
- 管理者ユーザ: `minio_admin`
- ストレージ: 5Gi (PersistentVolume)
- サービスタイプ: ClusterIP

### CNPG オペレーターのインストール

```bash
./1-install-cnpg-c.sh
```

**実行内容：**
1. ネームスペース作成: `postgresql-operator-system` と `edb`
2. Docker レジストリシークレット作成: `edb-pull-secret`（EDB コンテナイメージの取得用）
3. CNPG オペレーターのデプロイ（バージョン 1.28.1）
4. オペレーターの起動確認（タイムアウト: 300秒）

確認コマンド：
```bash
kubectl get pods -n postgresql-operator-system
```

### EPAS16 クラスタのデプロイ

```bash
./2-deploy-epas16.sh
```

**デプロイされるもの：**
- **クラスター名:** `epas16`
- **ネームスペース:** `edb`
- **インスタンス数:** 3（1プライマリ + 2スタンバイ）
- **イメージ:** `docker.enterprisedb.com/k8s/edb-postgres-advanced:16.11`
- **ストレージ:** 1Gi per instance
- **バックアップ設定:**
  - バックアップ先: MinIO (`s3://epas16-backups`)
  - 保持期間: 7日間
  - WAL 圧縮: gzip
  - 並列処理: 2

**作成されるサービス：**
- `epas16-rw` (read-write) - NodePort 30432（プライマリへの接続）
- `epas16-ro` (read-only) - ClusterIP（リードオンリー接続）  
- `epas16-r` (replica) - ClusterIP（レプリカへの接続）

スクリプトは自動的に以下を実行します：
1. `cluster-barman.yaml` の適用
2. バックアップ用シークレット作成
3. 60秒待機
4. デプロイメントの準備完了を確認（タイムアウト: 600秒）
5. `epas16-rw` サービスを NodePort に変更

### kubectl cnp による EPAS16 クラスタのステータス取得

```bash
kubectl -n edb cnp status epas16 -n edb

k -n edb cnp status epas16 -n edb

watch -n 5 kubectl -n edb cnp status epas16 -n edb
```

### EPAS16 クラスタ サービスの確認

```bash
kubectl -n edb get svc
```

出力例：
```
NAME        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
epas16-r    ClusterIP   10.96.127.18    <none>        5432/TCP         5m
epas16-ro   ClusterIP   10.96.234.24    <none>        5432/TCP         5m
epas16-rw   NodePort    10.96.111.202   <none>        5432:30432/TCP   5m
minio       ClusterIP   10.96.200.100   <none>        9000/TCP         10m
minio-console ClusterIP 10.96.50.50    <none>        9001/TCP         10m
```


## EPAS への接続

### cnp プラグインを利用する場合

```bash
k cnp status epas16 -n edb
```

### アプリケーションユーザーのパスワード取得

```bash
kubectl -n edb get secret epas16-app -o yaml | ./bin/decode-yaml.sh | grep password:
```

出力例：
```yaml
password: your_generated_password
```

### KIND ホストからの接続

```bash
psql "postgresql://app:<password>@localhost:5432/app"
```

### リモートホスト（ローカル PC）からの接続

```bash
psql "postgresql://app:<password>@<kind_host_ip>:5432/app"
```

`<kind_host_ip>` は KIND が実行されているホストのパブリック IP アドレスです。

### 接続先の使い分け

- **読み書き (プライマリ):** `epas16-rw:5432` - 全ての操作が可能
- **読み取り専用:** `epas16-ro:5432` - SELECT クエリを複数レプリカに分散
- **特定レプリカ:** `epas16-r:5432` - レプリカへの直接接続


## サンプルテーブルの作成

```bash
psql -h localhost -U app -d app -f ddl-dml/create-table-t1.sql
```

**作成される内容：**
- テーブル名: `t1`
- カラム: `id` (SERIAL), `name` (VARCHAR), `description` (TEXT), `created_at`, `updated_at`
- 3行のサンプルデータが挿入されます

確認コマンド：
```sql
SELECT * FROM t1;
```


## バックアップとリカバリ

### バックアップアーキテクチャ

`cluster-barman.yaml` で設定されているバックアップ構成：
- **バックアップツール:** Barman (Backup and Recovery Manager)
- **ストレージ:** MinIO (S3互換オブジェクトストレージ)
- **バケット:** `s3://epas16-backups`
- **保持期間:** 7日間（`retentionPolicy: "7d"`）
- **WAL アーカイブ:** gzip 圧縮、並列度 2
- **認証情報:** Secret `backup-storage-creds`

### スケジュールバックアップの設定

```bash
./4-apply-scheduled-backup.sh
```

**`scheduled-backup.yaml` の設定：**
- **リソース名:** `epas16-scheduled`
- **スケジュール:** `"0 */3 * * * *"` - 3分ごとに実行
- **Cron 形式:** 6フィールド（`秒 分 時 日 月 曜日`）
  - 例: `"0 0 2 * * *"` = 毎日午前2時0分0秒
  - 例: `"0 */10 * * * *"` = 10分ごと（0秒時点）
  - 例: `"0 */3 * * * *"` = 3分ごと（0秒時点 - デフォルト設定）
- **immediate:** `true` - リソース作成時に即座にバックアップを実行
- **suspend:** `false` - スケジュールバックアップを有効化
- **method:** `barmanObjectStore` - MinIO へのバックアップ

**注意:** CloudNativePG のスケジュールは6フィールド形式（秒を含む）です。標準的な5フィールド cron とは異なります。

### 手動バックアップの実行

```bash
./5-backup.sh
```

タイムスタンプ付きのバックアップが作成されます（例: `backup-epas16-0222-1530`）。

### バックアップの確認

```bash
# スケジュールバックアップの確認
kubectl get scheduledbackup -n edb

# バックアップ履歴の確認
kubectl get backup -n edb

# バックアップの詳細確認
kubectl describe backup <backup-name> -n edb
```

### MinIO でのバックアップ確認

MinIO コンソールにアクセスしてバックアップを確認：

```bash
./fwd-port-minio-console.sh
```

ブラウザで http://localhost:9001 にアクセス：
- **ユーザー名:** `minio_admin`
- **パスワード:** `minio_admin_0227`
- **バケット:** `epas16-backups`


## Grafana ダッシュボード

- テンプレート https://github.com/cloudnative-pg/grafana-dashboards/blob/main/charts/cluster/grafana-dashboard.json




## クリーンアップ

### オプション 1: CNPG リソースのみ削除

```bash
./8-del-cnpg-c.sh
```

**削除されるもの：**
- CNPG オペレーター（`postgresql-operator-system` ネームスペース）
- EPAS クラスター（`edb` ネームスペース）
- すべての関連リソース（Pods、Services、PVCs、Secrets）

KIND クラスター自体は残ります。再度 `./1-install-cnpg-c.sh` から実行してやり直すことができます。

### オプション 2: KIND クラスター全体の削除

```bash
./9-del-kind.sh
```

**削除されるもの：**
- KIND クラスター `my-k8s` 全体
- すべてのノード（コントロールプレーン + 3ワーカー）
- すべてのデータ、バックアップ、設定

**警告:** この操作は元に戻せません。すべてのデータが失われます。

## Tips と運用コマンド

### クラスター状態の確認

```bash
# クラスターの概要
kubectl get cluster -n edb

# Pod の状態
kubectl get pods -n edb

# CNPG プラグインを使用した詳細状態
kubectl cnpg status epas16 -n edb

# クラスターの詳細情報
kubectl describe cluster epas16 -n edb
```

### ログの確認

```bash
# プライマリ Pod のログ
kubectl logs -n edb epas16-1 -f

# オペレーターのログ
kubectl logs -n postgresql-operator-system deployment/postgresql-operator-controller-manager -f
```

### MinIO コンソールへのアクセス

バックアップストレージ（MinIO）のコンソールにアクセスするには：

```bash
./fwd-port-minio-console.sh
```

その後、ブラウザで http://localhost:9001 にアクセスします。
- **ユーザー名:** `minio_admin`
- **パスワード:** `minio_admin_0227`

### 利用可能なイメージタグの確認

CNPG や EPAS の Docker イメージタグを確認するには：

```bash
# CNPG オペレーターのバージョン一覧（例: 1.28.1）
./list-cnpg-tags.sh

# EPAS 全バージョンのタグ一覧（10.x, 11.x, 12.x, 13.x, 14.x, 15.x, 16.x）
./list-epas-tags.sh

# EPAS 16.x のタグ一覧（例: 16.11）
./list-epas16-tags.sh
```

**注意:** これらのスクリプトは `skopeo` と環境変数 `EDB_SUBSCRIPTION_TOKEN` を必要とします。

### ホストポートマッピングの確認

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

期待される出力：
```
NAMES                  PORTS
my-k8s-control-plane   0.0.0.0:6443->6443/tcp, 0.0.0.0:5432->30432/tcp, 0.0.0.0:5444->30444/tcp, 0.0.0.0:9000->39000/tcp, 0.0.0.0:9001->39001/tcp
my-k8s-worker          
my-k8s-worker2         
my-k8s-worker3         
``` 

### KIND の kubeconfig 取得とリモートアクセス

#### kubeconfig の取得

KIND クラスターの kubeconfig を取得し、kubectl で利用するには：

```bash
kind get kubeconfig --name my-k8s > kubeconfig.yaml
export KUBECONFIG=kubeconfig.yaml
kubectl cluster-info
```

これで `kubeconfig.yaml` にクラスター設定が出力され、そのシェルセッションで有効になります。

#### リモートホストから KIND クラスターへアクセス

リモートのローカル PC から KIND クラスターに接続する場合は、kubeconfig を修正します：

**修正前：**
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

**修正後：**
```yaml
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true  # 証明書検証をスキップ（テスト環境のみ）
    server: https://192.168.1.100:6443  # KIND ホストの実際の IP アドレスに変更
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

**変更点：**
1. `certificate-authority-data` を `insecure-skip-tls-verify: true` に変更
2. `server` の `0.0.0.0` を KIND ホストの実際の IP アドレスに変更

**警告:** `insecure-skip-tls-verify: true` は本番環境では使用しないでください。テスト環境専用です。

これで、ローカル PC から kubectl コマンドを実行できます：

```bash
export KUBECONFIG=/path/to/kubeconfig.yaml
kubectl get nodes
kubectl get pods -n edb
```


## トラブルシューティング

### Pod が起動しない場合

```bash
# Pod の状態確認
kubectl get pods -n edb

# Pod の詳細情報
kubectl describe pod <pod-name> -n edb

# イベント確認
kubectl get events -n edb --sort-by='.lastTimestamp'
```

### イメージプルエラー

```bash
# シークレットの確認
kubectl get secret edb-pull-secret -n edb

# シークレットの詳細確認
kubectl describe secret edb-pull-secret -n edb

# EDB_SUBSCRIPTION_TOKEN が正しく設定されているか確認
echo $EDB_SUBSCRIPTION_TOKEN
```

### バックアップが失敗する場合

```bash
# バックアップ状態の確認
kubectl get backup -n edb

# バックアップの詳細
kubectl describe backup <backup-name> -n edb

# MinIO Pod の状態確認
kubectl get pods -n edb | grep minio

# MinIO のログ確認
kubectl logs -n edb <minio-pod-name>
```

### データベースに接続できない場合

```bash
# サービスの確認
kubectl get svc -n edb

# NodePort の確認
kubectl get svc epas16-rw -n edb -o jsonpath='{.spec.ports[0].nodePort}'

# ポートフォワーディングで直接接続を試す
kubectl port-forward -n edb svc/epas16-rw 5432:5432
```


## 技術仕様

### クラスター構成
- **PostgreSQL バージョン:** EDB Postgres Advanced Server 16.11
- **インスタンス数:** 3（1プライマリ + 2スタンバイ）
- **レプリケーション:** ストリーミングレプリケーション（同期/非同期）
- **ストレージ:** 1Gi per instance（PersistentVolume）
- **高可用性:** 自動フェイルオーバー（CNPG オペレーターが管理）

### バックアップ構成
- **バックアップツール:** Barman 2.x
- **ストレージバックエンド:** MinIO (S3互換)
- **バックアップタイプ:** フルバックアップ + WAL アーカイブ
- **保持期間:** 7日間
- **圧縮:** gzip
- **並列処理:** 2ストリーム

### ネットワーク
- **CNI:** KIND デフォルト（kindnet）
- **kube-proxy モード:** IPVS
- **サービスタイプ:** ClusterIP + NodePort


## 参考文献

### 公式ドキュメント
- [EDB Postgres for Kubernetes - Installation and Upgrade](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/installation_upgrade/)
- [EDB Postgres for Kubernetes - Backup and Recovery](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/backup_recovery/)
- [CloudNativePG - Scheduled Backups](https://cloudnative-pg.io/documentation/current/backup/)
- [KIND - Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)

### コミュニティ
- [CloudNativePG GitHub](https://github.com/cloudnative-pg/cloudnative-pg)
- [EDB Community](https://www.enterprisedb.com/community)

