CREATE TEMP TABLE wal_baseline AS
SELECT
  pg_current_wal_lsn() AS start_lsn,
  clock_timestamp() AS start_ts;

-- run your INSERT/UPDATE workload here

SELECT
  pg_wal_lsn_diff(pg_current_wal_lsn(), start_lsn) AS wal_bytes_generated,
  EXTRACT(EPOCH FROM clock_timestamp() - start_ts) AS elapsed_seconds,
  pg_wal_lsn_diff(pg_current_wal_lsn(), start_lsn)
    / NULLIF(EXTRACT(EPOCH FROM clock_timestamp() - start_ts), 0) AS wal_bytes_per_sec,
  pg_size_pretty(
    (
      pg_wal_lsn_diff(pg_current_wal_lsn(), start_lsn)
      / NULLIF(EXTRACT(EPOCH FROM clock_timestamp() - start_ts), 0)
    )::bigint
  ) || '/s' AS wal_rate_pretty
FROM wal_baseline;