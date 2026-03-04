# PostgreSQL 16 Testing Workflow

## Overview

This GitHub Actions workflow (`postgresql-16-test.yml`) provides comprehensive testing for PostgreSQL 16, including:

- **Compatibility Testing**: Validates SQL operations, CRUD functionality, and PostgreSQL 16-specific features
- **Performance Benchmarking**: Uses pgbench and custom queries to measure database performance
- **Vulnerability Scanning**: Scans for critical and high-severity CVEs using Trivy
- **Integration Testing**: Tests concurrent connections, backup/restore, and stress scenarios

## Workflow Structure

### Jobs

#### 1. `compatibility-test`
Tests PostgreSQL 16 compatibility with:
- DDL/DML execution from `ddl-dml/` directory
- Basic CRUD operations (SELECT, INSERT, UPDATE, DELETE)
- Transactions and rollback functionality
- PostgreSQL 16 features (JSON/JSONB, window functions, CTEs)
- Index creation and query planning
- Deprecated feature detection

#### 2. `performance-test`
Measures database performance using:
- **pgbench**: Standard PostgreSQL benchmarking tool
  - Read-only test: 10 clients, 2 jobs, 1000 transactions
  - Read-write test: 10 clients, 2 jobs, 500 transactions
- **Custom tests**: 
  - Sequential and index scans with 10k rows
  - Join performance
  - Aggregation queries
  - Query statistics analysis

#### 3. `vulnerability-scan`
Security scanning with:
- **Trivy**: Scans `postgres:16-alpine` image
- Filters for CRITICAL and HIGH severity CVEs
- Generates JSON report artifact
- Optional CVE database lookup

#### 4. `integration-test`
Stress and integration testing:
- 20 concurrent connection test
- Connection pool validation
- pg_dump backup compatibility
- pg_restore functionality

#### 5. `summary`
Aggregates results and generates GitHub Step Summary

## Triggers

The workflow runs on:
- **Push**: to `main` or `develop` branches
- **Pull Request**: targeting `main` or `develop`
- **Schedule**: Daily at 2 AM UTC (to catch new vulnerabilities)
- **Manual**: via `workflow_dispatch`

## Configuration

Environment variables (customize as needed):
```yaml
POSTGRES_VERSION: '16'
POSTGRES_DB: testdb
POSTGRES_USER: testuser
POSTGRES_PASSWORD: testpass123
```

## Requirements

### Repository Setup
1. Ensure `ddl-dml/create-table-t1.sql` exists (or modify the workflow to point to your DDL files)
2. Enable GitHub Actions in your repository settings
3. Optionally, configure branch protection rules based on workflow results

### Permissions
The workflow requires:
- `contents: read` - to checkout code
- `actions: read` - to upload artifacts
- Default permissions are sufficient for most operations

## Usage

### Running Manually
1. Go to **Actions** tab in your GitHub repository
2. Select **PostgreSQL 16 Testing Suite**
3. Click **Run workflow**
4. Choose the branch and click **Run workflow**

### Viewing Results
- **Summary**: Check the workflow summary for overall status
- **Logs**: Each job provides detailed logs
- **Artifacts**: Download `trivy-vulnerability-report` for security scan results

### Interpreting Results

#### Success Criteria
- ✅ All compatibility tests pass
- ✅ Performance benchmarks complete without errors
- ✅ No blocking vulnerabilities (or acceptable risk documented)
- ✅ Integration tests succeed

#### Failure Scenarios
- ❌ SQL syntax errors (compatibility issue)
- ❌ Performance degradation (compare with baseline)
- ❌ Critical CVEs found (review and remediate)
- ❌ Connection or backup failures

## Customization

### Adding Custom Tests
Edit the workflow to add additional test steps:

```yaml
- name: Custom test
  run: |
    PGPASSWORD=${{ env.POSTGRES_PASSWORD }} psql \
      -h localhost \
      -U ${{ env.POSTGRES_USER }} \
      -d ${{ env.POSTGRES_DB }} \
      -f your-custom-test.sql
```

### Adjusting Performance Parameters
Modify pgbench parameters:
- `-c`: Number of concurrent clients
- `-j`: Number of threads
- `-t`: Number of transactions per client
- `-s`: Scale factor for initialization

### Vulnerability Scan Thresholds
To fail the workflow on vulnerabilities:

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'postgres:16-alpine'
    format: 'table'
    exit-code: '1'  # Change from '0' to '1' to fail on findings
    severity: 'CRITICAL,HIGH'
```

## Best Practices

1. **Run on Schedule**: Daily scans catch new CVEs quickly
2. **Review Reports**: Check Trivy artifacts for vulnerability details
3. **Baseline Performance**: Track performance metrics over time
4. **Update Tests**: Add new compatibility tests as features are used
5. **Monitor Failures**: Set up notifications for workflow failures

## PostgreSQL 16 Features Tested

- ✅ JSON/JSONB operations
- ✅ Window functions and CTEs
- ✅ Logical replication (configuration check)
- ✅ Parallel query execution
- ✅ Query planning and optimization
- ✅ Index types and performance
- ✅ Transaction isolation
- ✅ Statistics and monitoring

## Troubleshooting

### Common Issues

**Issue**: Connection refused to PostgreSQL
**Solution**: Check service health configuration and port mapping

**Issue**: DDL file not found
**Solution**: Verify file path in `ddl-dml/` directory

**Issue**: Trivy scan timeout
**Solution**: Increase timeout or reduce scan scope

**Issue**: Performance test inconsistency
**Solution**: Increase scale factor or transaction count for more stable results

## Additional Resources

- [PostgreSQL 16 Documentation](https://www.postgresql.org/docs/16/)
- [pgbench Documentation](https://www.postgresql.org/docs/current/pgbench.html)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## Contributing

To improve this workflow:
1. Fork the repository
2. Modify the workflow file
3. Test thoroughly
4. Submit a pull request with changes

## License

This workflow configuration is provided as-is for testing PostgreSQL 16 installations.
