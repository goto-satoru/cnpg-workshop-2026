#!/bin/bash
# ------------------------------------------------------------------------------
# 1) テーブル作成 & 1,000,000 件 INSERT スクリプト (EPAS: enterprisedb ユーザー)
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

echo "Cluster            : $CLUSTER_NAME (Namespace: $NS)"
echo "Database           : $DB_NAME"
echo "Creating table and inserting 1,000,000 records via $CNP_CMD cnp psql..."

$CNP_CMD cnp psql "$CLUSTER_NAME" -n "$NS" --  << 'EOF'
\timing on

CREATE TABLE IF NOT EXISTS test_upgrade_data (
    id INT PRIMARY KEY,
    val_text TEXT,
    val_num NUMERIC,
    created_at TIMESTAMP
);

TRUNCATE TABLE test_upgrade_data;

INSERT INTO test_upgrade_data (id, val_text, val_num, created_at)
SELECT 
    g,
    md5(g::text),
    round((random() * 100000)::numeric, 2),
    NOW() - (g || ' seconds')::interval
FROM generate_series(1, 1000000) AS g;

SELECT count(*) AS total_records FROM test_upgrade_data;
EOF

echo "Done. Now you can run ./check-data-integrity.sh to record sampling data."
