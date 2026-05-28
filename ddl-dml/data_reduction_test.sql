-- 0) Reset existing objects (safe for re-run)
DROP REDACTION POLICY IF EXISTS redact_customer_pii ON customer_pii;
DROP VIEW IF EXISTS customer_pii_redacted;
DROP TABLE IF EXISTS customer_pii CASCADE;

DROP FUNCTION IF EXISTS sec.mask_phone(varchar(13));
DROP FUNCTION IF EXISTS sec.mask_address(varchar(255));
DROP FUNCTION IF EXISTS sec.mask_my_number(char(14));
DROP FUNCTION IF EXISTS sec.mask_name(varchar(255));

-- 1) Base table (example)
CREATE TABLE IF NOT EXISTS customer_pii (
    id           BIGINT PRIMARY KEY,
    name         varchar(255),
    my_number    char(14),
    address      varchar(255),
    phone_number varchar(13)
);

-- 2) Roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pii_full_access') THEN
        CREATE ROLE pii_full_access;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_reader') THEN
        CREATE ROLE app_reader;
    END IF;
END$$;

-- 3) Helper masking functions for EPAS data redaction policy
CREATE SCHEMA IF NOT EXISTS sec;

CREATE OR REPLACE FUNCTION sec.mask_name(v varchar(255))
RETURNS varchar(255)
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT CASE
        WHEN v IS NULL OR length(v) = 0 THEN v
        WHEN length(v) = 1 THEN '*'
        ELSE (left(v, 1) || repeat('*', greatest(length(v) - 1, 1)))::varchar(255)
    END::varchar(255);
$$;

CREATE OR REPLACE FUNCTION sec.mask_my_number(v char(14))
RETURNS char(14)
LANGUAGE SQL
IMMUTABLE
AS $$
    -- keep only last 4 chars, preserve 14-char format
    SELECT CASE
        WHEN v IS NULL THEN NULL
        WHEN length(v) <= 4 THEN lpad('', 14, '*')::char(14)
        ELSE ('****-****-' || right(v, 4))::char(14)
    END::char(14);
$$;

CREATE OR REPLACE FUNCTION sec.mask_address(v varchar(255))
RETURNS varchar(255)
LANGUAGE SQL
IMMUTABLE
AS $$
    -- show only first token roughly, mask the rest
    SELECT CASE
        WHEN v IS NULL OR length(v) = 0 THEN v
        ELSE (split_part(v, ' ', 1) || ' ***')::varchar(255)
    END::varchar(255);
$$;

CREATE OR REPLACE FUNCTION sec.mask_phone(v varchar(13))
RETURNS varchar(13)
LANGUAGE SQL
IMMUTABLE
AS $$
    -- show only last 4 digits/chars
    SELECT CASE
        WHEN v IS NULL THEN NULL
        WHEN length(v) <= 4 THEN repeat('*', length(v))::varchar(13)
        ELSE ('***-***-' || right(regexp_replace(v, '\D', '', 'g'), 4))::varchar(13)
    END::varchar(13);
$$;

-- 4) Data redaction policy (EPAS native feature)
CREATE REDACTION POLICY redact_customer_pii ON customer_pii
FOR (NOT pg_has_role(current_user, 'pii_full_access', 'member'))
ADD COLUMN name USING sec.mask_name(name),
ADD COLUMN my_number USING sec.mask_my_number(my_number),
ADD COLUMN address USING sec.mask_address(address),
ADD COLUMN phone_number USING sec.mask_phone(phone_number);

-- 5) Privileges: both roles read table, policy controls redaction
REVOKE ALL ON customer_pii FROM PUBLIC;
REVOKE ALL ON customer_pii FROM app_reader;

GRANT SELECT ON customer_pii TO pii_full_access;          -- privileged sees clear data
GRANT SELECT ON customer_pii TO app_reader;               -- normal users see redacted data by policy

-- 6) Sample records
INSERT INTO customer_pii (id, name, my_number, address, phone_number)
VALUES
    (1001, 'YAMADA Taro',  '1234-5678-9012', 'Tokyo Chiyoda 1-1-1',   '090-1234-5678'),
    (1002, 'SATO Hanako',  '9876-5432-1098', 'Osaka Kita 2-3-4',      '080-2345-6789'),
    (1003, 'SUZUKI Ken',   '1111-2222-3333', 'Nagoya Naka 3-4-5',     '070-3456-7890'),
    (1004, 'TAKAHASHI Yui','4444-5555-6666', 'Fukuoka Hakata 4-5-6',  '090-4567-8901'),
    (1005, 'KOBAYASHI Rin','7777-8888-9999', 'Sapporo Chuo 5-6-7',    '080-5678-9012')
ON CONFLICT (id) DO UPDATE
SET
    name = EXCLUDED.name,
    my_number = EXCLUDED.my_number,
    address = EXCLUDED.address,
    phone_number = EXCLUDED.phone_number;
