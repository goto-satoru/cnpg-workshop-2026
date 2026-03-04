# Quick Start Guide - PostgreSQL 16 Testing

## 🚀 Getting Started

This workflow automatically tests PostgreSQL 16 for compatibility, performance, and security.

### Prerequisites
✅ GitHub repository with Actions enabled  
✅ DDL/DML files in `ddl-dml/` directory (already present)  
✅ No additional setup required - workflow uses GitHub's runners

### How to Use

#### Option 1: Automatic Triggers
The workflow runs automatically on:
- Pushes to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Daily at 2 AM UTC (scheduled)

#### Option 2: Manual Trigger
1. Navigate to **Actions** tab
2. Select **PostgreSQL 16 Testing Suite**
3. Click **Run workflow** button
4. Select branch and click **Run workflow**

### What Gets Tested

| Test Category | What's Checked | Duration |
|--------------|----------------|----------|
| **Compatibility** | SQL operations, PG16 features, CRUD | ~2-3 min |
| **Performance** | pgbench, query optimization, indexing | ~3-4 min |
| **Security** | CVE scan (CRITICAL/HIGH), image vulnerabilities | ~2-3 min |
| **Integration** | Concurrent connections, backup/restore | ~1-2 min |

### Understanding Results

#### ✅ Success
All tests passed - PostgreSQL 16 is working correctly

#### ❌ Failure
Check the failed job logs for details:
- **Compatibility failure**: SQL syntax or feature incompatibility
- **Performance failure**: Benchmark didn't complete or timed out
- **Security failure**: Critical vulnerabilities found (review required)
- **Integration failure**: Connection, backup, or restore issues

### Quick Examples

#### Running Your Own SQL Tests
Add files to `ddl-dml/` directory and they'll be automatically picked up.

Example structure:
```
ddl-dml/
├── create-table-t1.sql          # Already exists
├── additional-dml-tests.sql     # Already created
└── your-custom-test.sql         # Add your own
```

Then modify the workflow to include your test:
```yaml
- name: Run custom tests
  run: |
    PGPASSWORD=${{ env.POSTGRES_PASSWORD }} psql \
      -h localhost \
      -U ${{ env.POSTGRES_USER }} \
      -d ${{ env.POSTGRES_DB }} \
      -f ddl-dml/your-custom-test.sql
```

#### Viewing Vulnerability Reports
1. Go to completed workflow run
2. Scroll to **Artifacts** section
3. Download `trivy-vulnerability-report.json`
4. Review JSON for vulnerability details

#### Customizing Performance Tests
Edit the pgbench parameters in the workflow:
```yaml
pgbench \
  -c 20 \     # 20 concurrent clients (default: 10)
  -j 4 \      # 4 threads (default: 2)
  -t 2000 \   # 2000 transactions (default: 1000)
  --progress=10
```

### Common Modifications

#### Change PostgreSQL Version
```yaml
env:
  POSTGRES_VERSION: '16.2'  # Specify exact version
```

And update the service image:
```yaml
services:
  postgres:
    image: postgres:16.2-alpine  # Match version
```

#### Adjust Failure Threshold for CVEs
Make vulnerability scan fail the workflow:
```yaml
exit-code: '1'  # Change from '0' to '1'
```

#### Add Notifications
Add a notification step at the end:
```yaml
- name: Notify on failure
  if: failure()
  run: |
    # Add your notification logic
    curl -X POST your-webhook-url -d "Build failed"
```

### Local Testing (Optional)

Test SQL scripts locally before pushing:
```bash
# Start PostgreSQL 16 in Docker
docker run --name pg16-test \
  -e POSTGRES_PASSWORD=testpass123 \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_DB=testdb \
  -p 5432:5432 \
  -d postgres:16-alpine

# Run your DDL/DML
PGPASSWORD=testpass123 psql \
  -h localhost \
  -U testuser \
  -d testdb \
  -f ddl-dml/create-table-t1.sql

# Cleanup
docker stop pg16-test && docker rm pg16-test
```

### Troubleshooting

#### Issue: Workflow not triggering
**Solution**: Check branch names match (`main` or `develop`) or trigger manually

#### Issue: DDL file not found
**Solution**: Verify file exists in `ddl-dml/` directory relative to repo root

#### Issue: pgbench fails
**Solution**: Check database is initialized correctly and has sufficient resources

#### Issue: Trivy scan timeout
**Solution**: This is usually temporary - retry the workflow

### Next Steps

1. ✅ Commit and push the workflow file
2. ✅ Check the Actions tab for the first run
3. ✅ Review the test summary
4. ✅ Download vulnerability report if needed
5. ✅ Customize tests for your specific needs

### Support & Documentation

- 📖 [Full Documentation](README.md)
- 📖 [PostgreSQL 16 Release Notes](https://www.postgresql.org/docs/16/release-16.html)
- 📖 [GitHub Actions Docs](https://docs.github.com/en/actions)

---

**Pro Tip**: Set up branch protection rules to require this workflow to pass before merging PRs! 🎯
