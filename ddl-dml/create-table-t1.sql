-- Create sample table t1
CREATE TABLE IF NOT EXISTS t1 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add sample data (5 records)
INSERT INTO t1 (name, description) VALUES
    ('John Doe', 'Sample record 1'),
    ('Jane Smith', 'Sample record 2'),
    ('Alice Johnson', 'Sample record 3'),
    ('Bob Wilson', 'Sample record 4'),
    ('Carol Davis', 'Sample record 5');
