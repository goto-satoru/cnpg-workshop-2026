#!/bin/bash

# Load environment variables if available
if [ -f ./.env ]; then
  set -a
  source ./.env
  set +a
fi

NS="${NS_EPAS:-edb}"
SELECTOR="k8s.enterprisedb.io/cluster=epas16"
INTERVAL="${INTERVAL:-5}"

CMD="kubectl"
if ! command -v kubectl &>/dev/null && command -v oc &>/dev/null; then
  CMD="oc"
fi

echo "Monitoring EPAS pods and container IDs in namespace '$NS' (selector: $SELECTOR)..."
echo "Press Ctrl+C to exit."

watch -n "$INTERVAL" "$CMD get pods -n $NS -l $SELECTOR -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,CONTAINER:.status.containerStatuses[*].name,CONTAINER_ID:.status.containerStatuses[*].containerID,NODE:.spec.nodeName'"
