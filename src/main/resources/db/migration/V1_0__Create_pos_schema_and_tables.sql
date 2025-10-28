SET LOCAL search_path TO pos;
-- Baseline schema for application (idempotent)
CREATE SCHEMA IF NOT EXISTS pos;

-- Outbox table
CREATE TABLE IF NOT EXISTS pos.outbox (
  id BIGSERIAL PRIMARY KEY,
  aggregate_type VARCHAR(100),
  aggregate_id VARCHAR(100),
  type VARCHAR(200),        -- kafka topic
  payload JSONB,
  sent BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Payments
CREATE TABLE IF NOT EXISTS pos.payments (
  id VARCHAR(100) PRIMARY KEY,
  type VARCHAR(100),
  amount NUMERIC,
  currency VARCHAR(10),
  account_id VARCHAR(100),
  payload JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Transfers
CREATE TABLE IF NOT EXISTS pos.transfers (
  id VARCHAR(100) PRIMARY KEY,
  type VARCHAR(100),
  amount NUMERIC,
  from_account VARCHAR(100),
  to_account VARCHAR(100),
  payload JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Users
CREATE TABLE IF NOT EXISTS pos.users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE,
  hashed_password VARCHAR(255),
  role VARCHAR(50),
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Alerts
CREATE TABLE IF NOT EXISTS pos.alerts (
  id BIGSERIAL PRIMARY KEY,
  event_id VARCHAR(200),
  alert_type VARCHAR(100),
  source_type VARCHAR(100),
  amount NUMERIC,
  payload JSONB,
  kafka_partition BIGINT,
  kafka_offset BIGINT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_outbox_sent_created_at ON pos.outbox (sent, created_at);
CREATE INDEX IF NOT EXISTS idx_payments_account_id ON pos.payments (account_id);
CREATE INDEX IF NOT EXISTS idx_transfers_from_to ON pos.transfers (from_account, to_account);