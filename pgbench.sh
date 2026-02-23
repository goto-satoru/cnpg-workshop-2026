#!/bin/sh

CLUSTER_NAME="epas16"
NAMESPACE="edb"
DATABASE="pgbench"

DB_USER="postgres"
DB_PASSWORD="password"
DB_HOST="localhost"
DB_PORT="5432"

PGBENCH_SCALE="10"  # Scale factor (1 = ~10MB, adjust as needed)
PGBENCH_DURATION="60"  # Test duration in seconds
PGBENCH_JOBS="4"  # Number of parallel jobs
PGBENCH_CLIENTS="16"  # Number of concurrent clients

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== PGBench Initialization and Run ===${NC}"
echo ""

# Handle command-line arguments
if [ "$1" = "alter-password" ]; then
    if [ -z "$2" ]; then
        print_error "Usage: $0 alter-password <username> [new_password]"
        echo "  If new_password is omitted, you will be prompted for it securely"
        exit 1
    fi
    
    TARGET_USER=$2
    if [ -z "$3" ]; then
        read -sp "Enter new password for user '$TARGET_USER': " NEW_PASSWORD
        echo ""
        read -sp "Confirm password: " NEW_PASSWORD_CONFIRM
        echo ""
        if [ "$NEW_PASSWORD" != "$NEW_PASSWORD_CONFIRM" ]; then
            print_error "Passwords do not match"
            exit 1
        fi
    else
        NEW_PASSWORD=$3
    fi
    
    alter_user_password "$TARGET_USER" "$NEW_PASSWORD" "$4"
    exit $?
fi

# Function to print colored messages
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to alter a PostgreSQL user password
alter_user_password() {
    local TARGET_USER=$1
    local NEW_PASSWORD=$2
    local ADMIN_USER=${3:-"postgres"}
    
    if [ -z "$TARGET_USER" ] || [ -z "$NEW_PASSWORD" ]; then
        print_error "Usage: alter_user_password <username> <new_password> [admin_user]"
        return 1
    fi
    
    print_info "Setting up port-forward to cluster..."
    kubectl port-forward svc/"${CLUSTER_NAME}"-rw -n "$NAMESPACE" 5432:5432 > /dev/null 2>&1 &
    PF_PID=$!
    sleep 3
    
    print_info "Retrieving admin credentials..."
    ADMIN_SECRET=$(kubectl get secret "${CLUSTER_NAME}"-superuser -n "$NAMESPACE" -o json 2>/dev/null)
    if [ -z "$ADMIN_SECRET" ]; then
        print_warning "Superuser secret not found, trying with app credentials..."
        ADMIN_SECRET=$(kubectl get secret "${CLUSTER_NAME}"-app -n "$NAMESPACE" -o json 2>/dev/null)
    fi
    
    ADMIN_PASSWORD=$(echo "$ADMIN_SECRET" | jq -r '.data.password' | base64 -d)
    
    print_info "Altering password for user '$TARGET_USER'..."
    ALTER_OUTPUT=$(PGPASSWORD="$ADMIN_PASSWORD" psql -h "localhost" -p "5432" -U "$ADMIN_USER" -c "ALTER USER $TARGET_USER WITH PASSWORD '$NEW_PASSWORD';" 2>&1)
    ALTER_RESULT=$?
    
    if [ $ALTER_RESULT -eq 0 ]; then
        print_success "Password altered successfully for user '$TARGET_USER'"
    else
        print_error "Failed to alter password for user '$TARGET_USER'"
        echo "Error: $ALTER_OUTPUT"
    fi
    
    kill $PF_PID 2>/dev/null
}

# Check if cluster exists
print_info "Checking if cluster '$CLUSTER_NAME' exists..."
if ! kubectl get cluster "$CLUSTER_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
    print_error "Cluster '$CLUSTER_NAME' not found in namespace '$NAMESPACE'"
    echo "Deploy the cluster first:"
    echo "kubectl apply -f cluster.yaml"
    exit 1
fi

# Get cluster status
STATUS=$(kubectl get cluster "$CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
READY_INSTANCES=$(kubectl get cluster "$CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.status.readyInstances}' 2>/dev/null)

print_success "Cluster found: $CLUSTER_NAME (Status: $STATUS, Ready: $READY_INSTANCES)"
echo ""

# Setup port-forward to access cluster
print_info "Setting up port-forward to cluster..."
kubectl port-forward svc/"${CLUSTER_NAME}"-rw -n "$NAMESPACE" 5432:5432 > /dev/null 2>&1 &
PF_PID=$!
print_info "Waiting for port-forward to be ready..."
sleep 5

# Verify port-forward is ready
if ! kill -0 $PF_PID 2>/dev/null; then
    print_error "Port-forward process failed to start"
    exit 1
fi

# Get connection credentials
print_info "Retrieving connection credentials..."
APP_SECRET=$(kubectl get secret "${CLUSTER_NAME}"-app -n "$NAMESPACE" -o json 2>/dev/null)
if [ -z "$APP_SECRET" ]; then
    print_error "Could not retrieve app credentials"
    kill $PF_PID 2>/dev/null
    exit 1
fi

# Test connection
print_info "Testing database connection..."
print_info "Connection details: host=$DB_HOST, port=$DB_PORT, user=$DB_USER"
CONN_TEST=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "SELECT version();" 2>&1)
CONN_RESULT=$?

if [ $CONN_RESULT -ne 0 ]; then
    print_error "Failed to connect to database"
    echo "Error details: $CONN_TEST"
    echo ""
    echo "Troubleshooting tips:"
    echo "1. Verify cluster is running: kubectl get cluster $CLUSTER_NAME -n $NAMESPACE"
    echo "2. Check pods: kubectl get pods -n $NAMESPACE"
    echo "3. Check pod logs: kubectl logs -n $NAMESPACE -l cnpg.io/cluster=$CLUSTER_NAME"
    echo "4. Verify secrets: kubectl get secret ${CLUSTER_NAME}-app -n $NAMESPACE"
    kill $PF_PID 2>/dev/null
    exit 1
fi
print_success "Connection successful"
echo ""

# Check if pgbench database exists
print_info "Checking for existing pgbench database..."
DB_EXISTS=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -tc "SELECT 1 FROM pg_database WHERE datname='$DATABASE';" 2>/dev/null)

if [ -n "$DB_EXISTS" ]; then
    print_warning "Database '$DATABASE' already exists"
    read -p "Do you want to drop and recreate it? (y/N): " CONFIRM
    if [[ $CONFIRM =~ ^[Yy]$ ]]; then
        print_info "Dropping existing database..."
        DROP_OUTPUT=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "DROP DATABASE IF EXISTS $DATABASE;" 2>&1)
        DROP_RESULT=$?
        if [ $DROP_RESULT -eq 0 ]; then
            print_success "Database dropped"
        else
            print_error "Failed to drop database: $DROP_OUTPUT"
        fi
    else
        print_warning "Using existing database"
        SKIP_INIT="yes"
    fi
else
    print_info "Creating pgbench database..."
    CREATE_OUTPUT=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $DATABASE;" 2>&1)
    CREATE_RESULT=$?
    if [ $CREATE_RESULT -eq 0 ]; then
        print_success "Database created"
    else
        print_error "Failed to create database"
        echo "Error details: $CREATE_OUTPUT"
        echo ""
        print_info "Checking database permissions..."
        PERMS=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "SELECT datcreatedb FROM pg_user WHERE usename='$DB_USER';" 2>&1)
        echo "User permissions: $PERMS"
        echo ""
        echo "Alternative: Try running as postgres user:"
        echo "PGPASSWORD=\"$DB_PASSWORD\" psql -h $DB_HOST -p $DB_PORT -U postgres -c \"CREATE DATABASE $DATABASE;\""
        kill $PF_PID 2>/dev/null
        exit 1
    fi
fi

echo ""

# Initialize pgbench tables
if [ "$SKIP_INIT" != "yes" ]; then
    print_info "Initializing pgbench tables..."
    print_info "Scale factor: $PGBENCH_SCALE (approximately $((PGBENCH_SCALE * 10))MB)"
    echo ""
    
    PGPASSWORD="$DB_PASSWORD" pgbench \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DATABASE" \
        -i \
        -s "$PGBENCH_SCALE" \
        --quiet
    
    if [ $? -eq 0 ]; then
        print_success "PGBench tables initialized"
        echo ""
    else
        print_error "Failed to initialize pgbench tables"
        kill $PF_PID 2>/dev/null
        exit 1
    fi
fi

# Run pgbench
echo ""
print_info "Running pgbench performance test..."
print_info "Configuration:"
echo "  Duration: ${PGBENCH_DURATION}s"
echo "  Clients: $PGBENCH_CLIENTS"
echo "  Jobs: $PGBENCH_JOBS"
echo ""

PGPASSWORD="$DB_PASSWORD" pgbench \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DATABASE" \
    -c "$PGBENCH_CLIENTS" \
    -j "$PGBENCH_JOBS" \
    -T "$PGBENCH_DURATION" \
    -r \
    --progress=10

BENCH_RESULT=$?
echo ""

if [ $BENCH_RESULT -eq 0 ]; then
    print_success "PGBench test completed successfully!"
else
    print_error "PGBench test failed"
fi

echo ""
print_info "Useful commands:"
echo "   # Check database size"
echo "   PGPASSWORD=\"$DB_PASSWORD\" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -c \"SELECT pg_size_pretty(pg_database_size('$DATABASE'));\" -d $DATABASE"
echo ""
echo "   # View pgbench tables"
echo "   PGPASSWORD=\"$DB_PASSWORD\" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DATABASE -c \"\\dt\""
echo ""
echo "   # Run custom pgbench with different parameters"
echo "   PGPASSWORD=\"$DB_PASSWORD\" pgbench -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DATABASE -c 32 -j 8 -T 120 -r"
echo ""
echo "   # Clean up pgbench tables"
echo "   PGPASSWORD=\"$DB_PASSWORD\" pgbench -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DATABASE --cleanup"
echo ""

# Clean up port-forward
kill $PF_PID 2>/dev/null
print_success "Port-forward closed"
