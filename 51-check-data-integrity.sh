#!/bin/bash
# ------------------------------------------------------------------------------
# 2) 無作為抽出サンプリング検証スクリプト (前後比較用)
# ------------------------------------------------------------------------------

set -a
[ -f ./.env ] && source ./.env
set +a

NS="${NS_EPAS:-edb}"
CLUSTER_NAME="${1:-epas16}"
DB_NAME="${2:-public}"
USER_NAME="enterprisedb"

# CLI コマンドの選択 (oc または kubectl)
CNP_CMD="oc"
if ! command -v oc &>/dev/null && command -v kubectl &>/dev/null; then
  CNP_CMD="kubectl"
fi

echo "=================================================="
echo "Checking data via $CNP_CMD cnp psql (Cluster: $CLUSTER_NAME, Namespace: $NS)"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="

$CNP_CMD cnp psql "$CLUSTER_NAME" -n "$NS" --  << 'EOF'
-- 総件数確認
SELECT count(*) AS total_count FROM test_upgrade_data;

-- シード固定による無作為抽出 (100件) の整合性ハッシュ計算
SELECT setseed(0.42);

WITH sample AS (
    SELECT id, val_text, val_num, created_at
    FROM test_upgrade_data
    ORDER BY random()
    LIMIT 100
)
SELECT 
    count(*) AS sample_count,
    min(id) AS min_id,
    max(id) AS max_id,
    md5(string_agg(id::text || ':' || val_text || ':' || val_num::text || ':' || created_at::text, ',' ORDER BY id)) AS sample_checksum_md5
FROM sample;

-- テーブル全体のサマリチェックサム
SELECT 
    sum(id::bigint) AS sum_id,
    round(sum(val_num), 2) AS sum_num,
    md5(sum(id::bigint)::text || ':' || round(sum(val_num), 2)::text) AS full_table_summary_hash
FROM test_upgrade_data;
EOF
