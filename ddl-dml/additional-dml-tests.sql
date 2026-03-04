-- Additional DML test operations for PostgreSQL 16
-- This file can be used to extend testing beyond create-table-t1.sql

-- Test complex UPDATE operations
UPDATE t1 
SET 
    description = CONCAT('Updated on ', CURRENT_TIMESTAMP::TEXT),
    updated_at = CURRENT_TIMESTAMP
WHERE id IN (1, 2, 3);

-- Test batch INSERT
INSERT INTO t1 (name, description) VALUES
    ('Test User 6', 'Batch insert test 1'),
    ('Test User 7', 'Batch insert test 2'),
    ('Test User 8', 'Batch insert test 3'),
    ('Test User 9', 'Batch insert test 4'),
    ('Test User 10', 'Batch insert test 5');

-- Test INSERT with SELECT
INSERT INTO t1 (name, description)
SELECT 
    'Copied ' || name,
    'Copy of: ' || description
FROM t1
WHERE id <= 3;

-- Test UPDATE with JOIN (using subquery for compatibility)
UPDATE t1
SET description = 'Matched record'
WHERE id IN (
    SELECT id FROM t1 WHERE name LIKE 'Test%'
);

-- Test DELETE with conditions
DELETE FROM t1
WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '1 year'
   OR description IS NULL;

-- Test UPSERT (INSERT ON CONFLICT)
INSERT INTO t1 (id, name, description)
VALUES (1, 'Updated John Doe', 'Upserted record')
ON CONFLICT (id) DO UPDATE
SET 
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = CURRENT_TIMESTAMP;

-- Test transaction with SAVEPOINT
BEGIN;
    INSERT INTO t1 (name, description) VALUES ('Savepoint Test 1', 'First insert');
    SAVEPOINT sp1;
    INSERT INTO t1 (name, description) VALUES ('Savepoint Test 2', 'Second insert');
    ROLLBACK TO SAVEPOINT sp1;
    INSERT INTO t1 (name, description) VALUES ('Savepoint Test 3', 'Third insert');
COMMIT;

-- Test aggregate operations
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT name) as unique_names,
    MIN(created_at) as earliest_record,
    MAX(created_at) as latest_record
FROM t1;

-- Test GROUP BY with HAVING
SELECT 
    LEFT(name, 4) as name_prefix,
    COUNT(*) as count
FROM t1
GROUP BY LEFT(name, 4)
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- Test subquery operations
SELECT 
    id,
    name,
    description,
    (SELECT COUNT(*) FROM t1 t2 WHERE t2.id <= t1.id) as cumulative_count
FROM t1
ORDER BY id;

-- Test CASE expressions
SELECT 
    id,
    name,
    CASE 
        WHEN LENGTH(name) < 10 THEN 'Short'
        WHEN LENGTH(name) BETWEEN 10 AND 20 THEN 'Medium'
        ELSE 'Long'
    END as name_length_category,
    CASE
        WHEN created_at > CURRENT_TIMESTAMP - INTERVAL '1 day' THEN 'Recent'
        WHEN created_at > CURRENT_TIMESTAMP - INTERVAL '1 week' THEN 'This Week'
        ELSE 'Older'
    END as age_category
FROM t1;

-- Test string operations
SELECT 
    id,
    name,
    UPPER(name) as name_upper,
    LOWER(name) as name_lower,
    LENGTH(name) as name_length,
    REVERSE(name) as name_reversed,
    SUBSTRING(name FROM 1 FOR 10) as name_truncated
FROM t1
LIMIT 5;

-- Test date/time operations
SELECT 
    id,
    created_at,
    DATE(created_at) as created_date,
    EXTRACT(YEAR FROM created_at) as year,
    EXTRACT(MONTH FROM created_at) as month,
    EXTRACT(DAY FROM created_at) as day,
    TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') as formatted_date
FROM t1
LIMIT 5;

-- Test performance with EXPLAIN
EXPLAIN ANALYZE
SELECT * FROM t1 WHERE name LIKE '%Test%';

EXPLAIN (FORMAT JSON, ANALYZE, BUFFERS)
SELECT COUNT(*) FROM t1 GROUP BY LEFT(name, 1);

-- Verify final state
SELECT 
    'Final test summary' as status,
    COUNT(*) as total_rows,
    COUNT(DISTINCT name) as unique_names,
    SUM(CASE WHEN description LIKE '%Updated%' THEN 1 ELSE 0 END) as updated_rows
FROM t1;

-- Output success message
SELECT 'All DML tests completed successfully!' as result;
