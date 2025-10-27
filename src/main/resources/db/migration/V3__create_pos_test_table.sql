-- Create simple table for replication test
CREATE SCHEMA IF NOT EXISTS pos;

CREATE TABLE IF NOT EXISTS pos.test (
  id BIGSERIAL PRIMARY KEY,
  note TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_test_created_at ON pos.test (created_at);