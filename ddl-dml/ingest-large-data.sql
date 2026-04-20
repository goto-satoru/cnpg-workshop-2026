CREATE TABLE IF NOT EXISTS t1 (
	id SERIAL PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	description TEXT,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TEMP TABLE wal_baseline AS
SELECT pg_current_wal_lsn() AS start_lsn;

INSERT INTO t1 (name, description, created_at, updated_at)
SELECT
	'User ' || gs,
	'Sample record ' || gs,
	CURRENT_TIMESTAMP - (gs || ' seconds')::INTERVAL,
	CURRENT_TIMESTAMP - (gs || ' seconds')::INTERVAL
FROM generate_series(1, 1000000) AS gs;

SELECT COUNT(*) AS total_rows FROM t1;

SELECT
	start_lsn AS wal_lsn_before,
	pg_current_wal_lsn() AS wal_lsn_after,
	pg_wal_lsn_diff(pg_current_wal_lsn(), start_lsn) AS wal_bytes_generated,
	pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), start_lsn)) AS wal_size_generated
FROM wal_baseline;
