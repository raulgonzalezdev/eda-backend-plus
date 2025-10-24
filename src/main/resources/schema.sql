CREATE SCHEMA IF NOT EXISTS pos;

CREATE TABLE IF NOT EXISTS pos.users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    role VARCHAR(50),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pos.outbox (
    id BIGSERIAL PRIMARY KEY,
    aggregate_type VARCHAR(255) NOT NULL,
    aggregate_id VARCHAR(255) NOT NULL,
    type VARCHAR(255) NOT NULL,
    payload JSONB,
    sent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pos.alerts (
    id BIGSERIAL PRIMARY KEY,
    event_id VARCHAR(255),
    alert_type VARCHAR(255) NOT NULL,
    source_type VARCHAR(255),
    amount NUMERIC(10, 2),
    payload JSONB,
    kafka_partition INTEGER,
    kafka_offset BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pos.payments (
    id VARCHAR(255) PRIMARY KEY,
    type VARCHAR(255),
    amount NUMERIC(10, 2),
    currency VARCHAR(10),
    account_id VARCHAR(255),
    payload JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pos.transfers (
    id VARCHAR(255) PRIMARY KEY,
    type VARCHAR(255),
    amount NUMERIC(10, 2),
    from_account VARCHAR(255),
    to_account VARCHAR(255),
    payload JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);