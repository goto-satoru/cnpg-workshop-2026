#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e
# Treat unset variables as an error
set -u

CNPG_NAMESPACE=postgresql-operator-system
EPAS_NAMESPACE=edb 
CLUSTER_CRD_BASE=postgresql.k8s.enterprisedb.io

# Check if CNPG_NAMESPACE is set
if [ -z "${CNPG_NAMESPACE}" ]; then
    echo "Error: CNPG_NAMESPACE is not set." >&2
    exit 1
fi

# Define output directory with a timestamp
TIMESTAMP=$(date +"%y%m%d_%H%M")
OUTPUT_DIR="./cnpg_report_${TIMESTAMP}"
TARBALL="${OUTPUT_DIR}.tar.gz"

echo "=== Starting OpenShift/K8s Environment Information Gathering ==="
echo "Creating output directory: ${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Helper function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: '$1' command could not be found. Please install it and log in." >&2
        exit 1
    fi
}

# Verify 'oc' or 'kubectl' is installed (defaults to oc, falls back to kubectl if needed)
if command -v oc &> /dev/null; then
    CLI="oc"
else 
    echo "Error: 'oc' not found in your PATH." >&2
    exit 1
fi

echo "Using CLI tool: ${CLI}"

# Verify active session / cluster connectivity
echo "Checking cluster connectivity..."
if ! ${CLI} cluster-info &> /dev/null; then
    echo "Error: Cannot connect to the cluster. Please ensure you are logged in (${CLI} login)." >&2
    exit 1
fi

echo "--------------------------------------------------"
echo "Gathering data... (This might take a few moments)"
echo "--------------------------------------------------"

# Helper: extract tag or digest suffix from image reference
extract_image_version() {
    image_ref="$1"
    if [ -z "${image_ref}" ]; then
        echo "unknown"
        return
    fi

    case "${image_ref}" in
        *@*)
            echo "${image_ref##*@}"
            ;;
        *:*)
            echo "${image_ref##*:}"
            ;;
        *)
            echo "latest"
            ;;
    esac
}

# 1. Cluster, CloudNativePG Operator, and EPAS/PostgreSQL Versions
echo "[1/7] Gathering Version Info (including CNPG/EPAS)..."
{
    echo "=== Client & Server Version ==="
    ${CLI} version
    printf '\n=== OpenShift Cluster Version (if applicable) ===\n'
    ${CLI} get clusterversion 2>/dev/null || echo "Not an OpenShift cluster or insufficient permissions."

    printf '\n=== CloudNativePG Operator Version ===\n'
    CNPG_IMAGE=""


    # Prefer cnpg-system and then postgresql-operator-system.
    if ${CLI} -n $CNPG_NAMESPACE get deploy postgresql-operator-controller-manager &>/dev/null; then
        CNPG_IMAGE="$(${CLI} -n $CNPG_NAMESPACE get deploy postgresql-operator-controller-manager -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
        echo "namespace=$CNPG_NAMESPACE"
    else
        # Last resort: search all deployment images for CNPG operator image name.
        CNPG_IMAGE="$(${CLI} get deploy -A -o jsonpath='{range .items[*]}{.spec.template.spec.containers[*].image}{"\n"}{end}' 2>/dev/null | grep -m1 'cloudnative-pg/cloudnative-pg' || true)"
        echo "namespace=unknown"
    fi

    if [ -n "${CNPG_IMAGE}" ]; then
        echo "image=${CNPG_IMAGE}"
        echo "version=$(extract_image_version "${CNPG_IMAGE}")"
    else
        echo "CloudNativePG operator image not found."
    fi

    printf '\n=== EPAS Version ===\n'
    if ${CLI} get crd clusters.$CLUSTER_CRD_BASE &>/dev/null; then
        echo "CNPG Cluster resources:"
        ${CLI} get cluster.$CLUSTER_CRD_BASE -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,IMAGE:.spec.imageName' 2>/dev/null || true

        EPAS_IMAGES="$(${CLI} get cluster.$CLUSTER_CRD_BASE -A -o jsonpath='{range .items[*]}{.spec.imageName}{"\n"}{end}' 2>/dev/null | grep -Ei 'epas|enterprisedb|edb' || true)"

        if [ -n "${EPAS_IMAGES}" ]; then
            echo "Detected EPAS image(s):"
            echo "${EPAS_IMAGES}" | while IFS= read -r img; do
                [ -n "${img}" ] || continue
                echo "- image=${img}"
                echo "  version=$(extract_image_version "${img}")"
            done
        else
            echo "No CNPG cluster images found."
        fi
    else
        echo "CNPG Cluster CRD (clusters.$CLUSTER_CRD_BASE) not found."

        # Fallback: inspect running pod images for EPAS/EDB names.
        EPAS_POD_IMAGES="$(${CLI} get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' 2>/dev/null | grep -Ei 'epas|enterprisedb|edb' || true)"
        if [ -n "${EPAS_POD_IMAGES}" ]; then
            echo "Detected EPAS/EDB image(s) from pods:"
            echo "${EPAS_POD_IMAGES}" | sort -u | while IFS= read -r img; do
                [ -n "${img}" ] || continue
                echo "- image=${img}"
                echo "  version=$(extract_image_version "${img}")"
            done
        else
            echo "No EPAS/EDB images detected in running pods."
        fi
    fi
} > "${OUTPUT_DIR}/version_info.txt"

# 2. Namespaces / Projects
echo "[2/7] Gathering Namespaces/Projects..."
{
    echo "=== All Namespaces ==="
    ${CLI} get namespaces -o wide
    if [ "$CLI" = "oc" ]; then
        printf '\n=== OpenShift Projects (if applicable) ===\n'
        if oc api-resources --no-headers 2>/dev/null | awk '{print $1}' | grep -qx "projects"; then
            oc get projects
        else
            echo "Projects resource not available in this cluster/context."
        fi
    fi
} > "${OUTPUT_DIR}/namespaces.txt"

# 3. Services (Across all namespaces)
echo "[3/7] Gathering Services..."
{
    echo "=== All Services (Cluster-wide) ==="
    ${CLI} get svc --all-namespaces -o wide
    printf '\n=== OpenShift Routes (if applicable) ===\n'
    ${CLI} get routes --all-namespaces 2>/dev/null || echo "Routes not supported/available in this context."
} > "${OUTPUT_DIR}/services.txt"

# 4. Events
echo "[4/7] Gathering Cluster Events..."
{
    echo "=== Warning Events (Last 1 hour sort) ==="
    ${CLI} get events --all-namespaces --sort-by='.metadata.creationTimestamp' | grep -i "warning" || echo "No Warning events found."
    printf '\n=== Error-like Events (Failed/Error/BackOff) ===\n'
    ${CLI} get events --all-namespaces --sort-by='.metadata.creationTimestamp' | grep -Ei 'error|failed|fail|backoff|crashloopbackoff' || echo "No error-like events found."
    printf '\n=== All Cluster Events (Sorted by Time) ===\n'
    ${CLI} get events --all-namespaces --sort-by='.metadata.creationTimestamp'
} > "${OUTPUT_DIR}/events.txt"

# 5. Storage (StorageClass, PersistentVolume, PersistentVolumeClaim)
echo "[5/7] Gathering Storage Resources (SC, PV, PVC)..."
{
    echo "=== StorageClasses ==="
    ${CLI} get sc -o wide
    printf '\n=== PersistentVolumes ===\n'
    ${CLI} get pv -o wide
    printf '\n=== PersistentVolumeClaims (Cluster-wide) ===\n'
    ${CLI} get pvc --all-namespaces -o wide
} > "${OUTPUT_DIR}/storage.txt"

# 6. Backups
echo "[6/8] Gathering Backups..."
{
    echo "=== Backup List (oc get backup) ==="
    ${CLI} get backup -A 2>/dev/null || ${CLI} get backups -A 2>/dev/null || echo "Backup resource not available in this cluster/context."
} > "${OUTPUT_DIR}/backups.txt"

# 7. EPAS/CNPG Cluster Status
echo "[7/8] Gathering EPAS/CNPG Cluster Status..."
{
    echo "=== EPAS/CNPG Cluster Status ==="
    if ${CLI} get cluster -A &>/dev/null; then
        ${CLI} get cluster -A
        printf '\n=== Detailed EPAS/CNPG Cluster Status ===\n'
        ${CLI} get cluster -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.readyInstances,INSTANCES:.spec.instances,PRIMARY:.status.currentPrimary,STATUS:.status.phase,IMAGE:.spec.imageName,AGE:.metadata.creationTimestamp'

        printf '\n=== oc cnp status Per Cluster ===\n'
        if ${CLI} cnp --help >/dev/null 2>&1; then
            ${CLI} get cluster -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' \
                | while IFS=' ' read -r ns name; do
                    [ -n "${ns}" ] || continue
                    [ -n "${name}" ] || continue
                    printf '\n--- %s/%s ---\n' "${ns}" "${name}"
                    ${CLI} cnp status "${name}" -n "${ns}" || echo "Failed to fetch cnp status for ${ns}/${name}."
                done
        else
            echo "'oc cnp' plugin/command not available in this environment."
        fi
    elif ${CLI} get crd clusters.postgresql.cnpg.io &>/dev/null; then
        ${CLI} get clusters.postgresql.cnpg.io -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.readyInstances,INSTANCES:.spec.instances,PRIMARY:.status.currentPrimary,STATUS:.status.phase,IMAGE:.spec.imageName,AGE:.metadata.creationTimestamp'
        printf '\n=== Full CNPG Cluster Summary (YAML) ===\n'
        ${CLI} get clusters.postgresql.cnpg.io -A -o yaml
    else
        echo "CNPG Cluster CRD (clusters.postgresql.cnpg.io) not found."
    fi
} > "${OUTPUT_DIR}/epas_cluster_status.txt"

# 8. General Cluster Runtime Health (Bonus snapshot)
echo "[8/8] Gathering Node and Pod Status Snapshots..."
{
    echo "=== Cluster Nodes ==="
    ${CLI} get nodes -o wide
    printf '\n=== Resource Usage (Nodes) ===\n'
    ${CLI} top nodes 2>/dev/null || echo "Metrics-server not available."
    printf '\n=== Non-Running Pods Snapshot ===\n'
    ${CLI} get pods --all-namespaces -o wide | grep -v -E "Running|Completed" || echo "All pods are healthy/completed."
} > "${OUTPUT_DIR}/cluster_health_snapshot.txt"

echo "--------------------------------------------------"
echo "Data gathering complete."
echo "Archiving results..."

# Compress the output folder
tar -czf "${TARBALL}" -C "$(dirname "${OUTPUT_DIR}")" "$(basename "${OUTPUT_DIR}")"

# Clean up the raw directory, leaving only the tarball
# rm -rf "${OUTPUT_DIR}"

echo "=== Success ==="
echo "All data has been saved and compressed to: ${TARBALL}"
