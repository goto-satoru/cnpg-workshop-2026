#!/usr/bin/env bash
set -euo pipefail

NS="edb"
CLUSTER="epas16"
BUCKET="barman"
PREFIX="epas16"
ENDPOINT="http://minio.edb.svc.cluster.local:9000"
MC_ENDPOINT="http://localhost:9000"
MC_ALIAS="local"
SINCE="30m"
WAL=""
LABEL_KEY=""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
print_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
print_ng() { echo -e "${RED}[NG]${NC} $*"; }

usage() {
  cat <<EOF
Usage:
  $0 -w <24hex WAL> [options]

Required:
  -w, --wal        WAL segment name (example: 00000003000000000000000C)

Options:
  -n, --namespace  Kubernetes namespace (default: ${NS})
  -c, --cluster    CNPG Cluster name (default: ${CLUSTER})
  -b, --bucket     S3 bucket name (default: ${BUCKET})
  -p, --prefix     S3 prefix/server name (default: ${PREFIX})
  -e, --endpoint   S3 endpoint URL (default: ${ENDPOINT})
  -m, --mc-alias   mc alias name (default: ${MC_ALIAS})
  -s, --since      kubectl logs --since value (default: ${SINCE})
  -h, --help       Show help

Examples:
  $0 -w 00000003000000000000000C
  $0 -n edb -c epas16 -w 00000002000000000000000C -m local
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    print_ng "Required command not found: $cmd"
    exit 1
  fi
}

is_valid_wal() {
  [[ "$1" =~ ^[0-9A-Fa-f]{24}$ ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace)
      NS="$2"; shift 2 ;;
    -c|--cluster)
      CLUSTER="$2"; shift 2 ;;
    -b|--bucket)
      BUCKET="$2"; shift 2 ;;
    -p|--prefix)
      PREFIX="$2"; shift 2 ;;
    -e|--endpoint)
      ENDPOINT="$2"; shift 2 ;;
    -m|--mc-alias)
      MC_ALIAS="$2"; shift 2 ;;
    -s|--since)
      SINCE="$2"; shift 2 ;;
    -w|--wal)
      WAL="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      print_ng "Unknown option: $1"
      usage
      exit 1 ;;
  esac
done

if [[ -z "$WAL" ]]; then
  print_ng "WAL is required. Use -w <24hex WAL>."
  usage
  exit 1
fi

if ! is_valid_wal "$WAL"; then
  print_ng "Invalid WAL format: $WAL"
  print_info "Expected 24 hex characters, e.g. 00000003000000000000000C"
  exit 1
fi

require_cmd kubectl
require_cmd mc

if ! kubectl get ns "$NS" >/dev/null 2>&1; then
  print_ng "Namespace not found: $NS"
  exit 1
fi

print_info "Target namespace: $NS"
print_info "Target cluster:   $CLUSTER"
print_info "Target WAL:       $WAL"
print_info "Object store:     s3://$BUCKET/$PREFIX (alias: $MC_ALIAS)"
print_info "Endpoint:         $ENDPOINT"
echo

if kubectl -n "$NS" get pod -l "k8s.enterprisedb.io/cluster=$CLUSTER" -o name 2>/dev/null | grep -q .; then
  LABEL_KEY="k8s.enterprisedb.io/cluster"
elif kubectl -n "$NS" get pod -l "cnpg.io/cluster=$CLUSTER" -o name 2>/dev/null | grep -q .; then
  LABEL_KEY="cnpg.io/cluster"
else
  print_ng "No pod found with labels k8s.enterprisedb.io/cluster=$CLUSTER or cnpg.io/cluster=$CLUSTER in namespace $NS"
  exit 1
fi

print_ok "Using label selector: ${LABEL_KEY}=${CLUSTER}"
POD="$(kubectl -n "$NS" get pod -l "${LABEL_KEY}=$CLUSTER" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "$POD" ]]; then
  print_ng "No pod found with label ${LABEL_KEY}=$CLUSTER in namespace $NS"
  exit 1
fi
print_ok "Using pod: $POD"

OBJ_PREFIX="${WAL:0:16}"
OBJ_NAME="${WAL}.gz"
OBJ_PATH="${MC_ALIAS}/${BUCKET}/${PREFIX}/wals/${OBJ_PREFIX}/${OBJ_NAME}"

echo
print_info "Step 1/4: Check object exists from mc"
MC_EXISTS=0
if mc stat "$OBJ_PATH" >/dev/null 2>&1; then
  MC_EXISTS=1
  print_ok "Object exists: $OBJ_PATH"
else
  print_warn "Object not found from mc path: $OBJ_PATH"
fi

if command -v jq >/dev/null 2>&1; then
  LAST_MODIFIED="$(mc ls --recursive --json "${MC_ALIAS}/${BUCKET}/${PREFIX}/wals" 2>/dev/null | jq -r --arg obj "$OBJ_NAME" 'select(.key|endswith($obj)) | .lastModified' | tail -1)"
  if [[ -n "${LAST_MODIFIED:-}" ]]; then
    print_info "Object lastModified (UTC): ${LAST_MODIFIED}"
  fi
fi

echo
print_info "Step 2/4: Probe WAL restore from pod"
TMP_TARGET="/tmp/${WAL}"
set +e
echo "kubectl -n $NS exec "$POD" -- sh -lc barman-cloud-wal-restore --endpoint-url '$ENDPOINT' --cloud-provider aws-s3 's3://$BUCKET' '$PREFIX' '$WAL' '$TMP_TARGET'"
kubectl -n "$NS" exec "$POD" -- sh -lc "barman-cloud-wal-restore --endpoint-url '$ENDPOINT' --cloud-provider aws-s3 's3://$BUCKET' '$PREFIX' '$WAL' '$TMP_TARGET' && ls -lh '$TMP_TARGET'"
RESTORE_RC=$?
set -e

if [[ $RESTORE_RC -eq 0 ]]; then
  print_ok "Pod-side wal restore probe succeeded"
  RESTORE_OK=1
else
  print_warn "Pod-side wal restore probe failed"
  RESTORE_OK=0
fi

echo
print_info "Step 3/4: Collect wal-restore logs"
echo "kubectl -n $NS logs -l ${LABEL_KEY}=$CLUSTER --all-containers=true --since=$SINCE | grep -E 'wal-restore|${WAL}|end-of-wal-stream|Restored WAL file|WAL file not found'"
LOG_MATCH="$(kubectl -n "$NS" logs -l "${LABEL_KEY}=$CLUSTER" --all-containers=true --since="$SINCE" 2>/dev/null | grep -E "wal-restore|${WAL}|end-of-wal-stream|Restored WAL file|WAL file not found" || true)"
if [[ -n "$LOG_MATCH" ]]; then
  echo "$LOG_MATCH" | tail -n 60
else
  print_warn "No matching wal-restore logs found in --since=$SINCE"
fi

echo
print_info "Step 4/4: Timeline-related quick check"
TL="${WAL:0:8}"
print_info "Current timeline prefix in WAL: ${TL}"

echo "mc ls --recursive ${MC_ALIAS}/${BUCKET}/${PREFIX}/wals"
mc ls --recursive ${MC_ALIAS}/${BUCKET}/${PREFIX}/wals | grep \.history 
HISTORY_COUNT="$(mc ls --recursive "${MC_ALIAS}/${BUCKET}/${PREFIX}/wals" 2>/dev/null | grep -c '\.history' || true)"
if [[ "${HISTORY_COUNT}" -gt 0 ]]; then
  print_ok "Timeline history files exist (${HISTORY_COUNT} file(s))"
else
  print_warn "No timeline history file detected under ${MC_ALIAS}/${BUCKET}/${PREFIX}/wals"
fi

echo
print_info "Verdict"
if [[ $RESTORE_OK -eq 1 && $MC_EXISTS -eq 1 ]]; then
  print_ok "OK: object is visible and pod can restore it now"
  print_info "If logs still show intermittent not found, timing race or parallel prefetch miss is likely."
  exit 0
fi

if [[ $RESTORE_OK -eq 0 && $MC_EXISTS -eq 1 ]]; then
  print_warn "WARN: object exists in mc, but pod probe failed"
  print_info "Likely causes: endpoint/credential mismatch, DNS/network path, temporary store inconsistency."
  exit 2
fi

if [[ $RESTORE_OK -eq 1 && $MC_EXISTS -eq 0 ]]; then
  print_warn "WARN: pod probe succeeded but mc path did not find object"
  print_info "Likely causes: wrong mc alias/bucket/prefix on local side."
  exit 2
fi

print_ng "NG: object not found by mc and pod probe failed"
print_info "This can be a real archive gap, or wrong bucket/prefix/endpoint settings."
exit 3
