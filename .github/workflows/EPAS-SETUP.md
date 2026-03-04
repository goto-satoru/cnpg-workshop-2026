# EPAS 16.13 Configuration Guide

## Required GitHub Secrets

To use EPAS (EDB Postgres Advanced Server) in GitHub Actions, you need to configure authentication for the EDB Docker registry.

### Setting Up EDB_SUBSCRIPTION_TOKEN

1. **Navigate to Repository Settings**
   - Go to your GitHub repository
   - Click **Settings** → **Secrets and variables** → **Actions**

2. **Create New Repository Secret**
   - Click **New repository secret**
   - Name: `EDB_SUBSCRIPTION_TOKEN`
   - Value: Your EDB subscription token (get from your `.env` file or EDB account)

3. **Verify Secret**
   - The secret should appear in the list (value will be hidden)
   - The workflow will use it as `${{ secrets.EDB_SUBSCRIPTION_TOKEN }}`

## Getting Your EDB Subscription Token

### Option 1: From Your .env File
```bash
# Check your local .env file
cat .env | grep EDB_SUBSCRIPTION_TOKEN
```

### Option 2: From EDB Account
1. Log in to [EDB Customer Portal](https://www.enterprisedb.com/accounts/profile)
2. Navigate to **Account** → **API Keys**
3. Copy your subscription token
4. Store it securely in GitHub Secrets

## EPAS vs PostgreSQL Differences

The workflow tests EPAS 16.13, which includes:
- ✅ PostgreSQL 16 core functionality
- ✅ Oracle compatibility features
- ✅ Advanced security features
- ✅ Performance enhancements
- ✅ Enterprise-grade support

### Key Configuration Changes

**Image:**
- Before: `postgres:16-alpine`
- After: `docker.enterprisedb.com/k8s/edb-postgres-advanced:16.13`

**Authentication:**
- Registry: `docker.enterprisedb.com`
- Username: `k8s`
- Password: `${{ secrets.EDB_SUBSCRIPTION_TOKEN }}`

**EULA Acceptance:**
- Environment variable: `ACCEPT_EULA: 'Yes'` (required for EPAS)

## Testing EPAS Locally

### With Docker
```bash
# Load your token
source .env

# Run EPAS container
docker login docker.enterprisedb.com -u k8s -p $EDB_SUBSCRIPTION_TOKEN

docker run --name epas16-test \
  -e POSTGRES_PASSWORD=testpass123 \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_DB=testdb \
  -e ACCEPT_EULA=Yes \
  -p 5432:5432 \
  -d docker.enterprisedb.com/k8s/edb-postgres-advanced:16.13

# Test connection
PGPASSWORD=testpass123 psql -h localhost -U testuser -d testdb -c "SELECT version();"

# Cleanup
docker stop epas16-test && docker rm epas16-test
```

### Verifying EPAS Features
```sql
-- Check EPAS-specific version
SELECT version();
-- Should show "EnterpriseDB" in the output

-- Check Oracle compatibility
SHOW edb_redwood_date;
SHOW edb_redwood_strings;

-- Test Oracle-compatible features
SELECT SYSDATE FROM DUAL;
```

## Troubleshooting

### Issue: Authentication Failed
**Error:** `Error response from daemon: Get https://docker.enterprisedb.com/v2/: unauthorized`

**Solution:**
1. Verify `EDB_SUBSCRIPTION_TOKEN` is set in GitHub Secrets
2. Check the token hasn't expired
3. Ensure the token has access to `edb-postgres-advanced` images

### Issue: EULA Not Accepted
**Error:** Container fails to start

**Solution:** Ensure `ACCEPT_EULA: 'Yes'` is set in environment variables

### Issue: Image Pull Timeout
**Error:** Timeout pulling EPAS image

**Solution:** 
- EPAS images are larger than Alpine PostgreSQL (~400MB vs ~230MB)
- GitHub Actions should handle this, but may take longer on first pull
- Consider adjusting `health-retries` if needed

### Issue: Feature Not Available
**Error:** Certain Oracle compatibility features not working

**Solution:**
- Check if Oracle compatibility mode is enabled
- Set `edb_redwood_date = true` and `edb_redwood_strings = true` if needed
- Consult [EPAS documentation](https://www.enterprisedb.com/docs/epas/latest/)

## Workflow Updates Summary

The workflow now:
1. ✅ Uses EPAS 16.13 instead of PostgreSQL 16
2. ✅ Authenticates with EDB Docker registry
3. ✅ Tests all PostgreSQL 16 compatibility
4. ✅ Works with your existing DDL/DML scripts
5. ✅ Scans EPAS image for vulnerabilities
6. ✅ Tests EPAS-specific features

## Additional EPAS Testing

To test EPAS-specific features, you can add:

```yaml
- name: Test EPAS Oracle Compatibility
  run: |
    cat << 'EOF' > test-epas-features.sql
    -- Test Oracle compatibility mode
    SHOW edb_redwood_date;
    SHOW edb_redwood_strings;
    
    -- Test DUAL table
    SELECT 1 FROM DUAL;
    
    -- Test SYSDATE
    SELECT SYSDATE FROM DUAL;
    
    -- Test packages (if available)
    SELECT * FROM pg_available_extensions WHERE name LIKE '%edb%';
    EOF
    
    PGPASSWORD=${{ env.POSTGRES_PASSWORD }} psql \
      -h localhost \
      -U ${{ env.POSTGRES_USER }} \
      -d ${{ env.POSTGRES_DB }} \
      -f test-epas-features.sql
```

## Security Considerations

- 🔐 Never commit `EDB_SUBSCRIPTION_TOKEN` to git
- 🔐 Use GitHub Secrets for sensitive credentials
- 🔐 Regularly rotate subscription tokens
- 🔐 Review Trivy scan results for vulnerabilities
- 🔐 Keep EPAS version updated with security patches

## Support Resources

- 📖 [EPAS Documentation](https://www.enterprisedb.com/docs/epas/latest/)
- 📖 [EDB Support Portal](https://support.enterprisedb.com/)
- 📖 [EPAS Release Notes](https://www.enterprisedb.com/docs/epas/latest/epas_rel_notes/)
- 📖 [Oracle Compatibility Guide](https://www.enterprisedb.com/docs/epas/latest/epas_compat_reference/)

## Next Steps

1. ✅ Set `EDB_SUBSCRIPTION_TOKEN` in GitHub Secrets
2. ✅ Push the updated workflow to GitHub
3. ✅ Run the workflow and verify EPAS connection
4. ✅ Review test results and vulnerability scan
5. ✅ Add EPAS-specific tests as needed

---

**Note:** EPAS requires a valid EDB subscription. Contact EDB if you need assistance with licensing or subscription tokens.
