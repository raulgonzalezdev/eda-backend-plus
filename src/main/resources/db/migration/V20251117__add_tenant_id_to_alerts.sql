-- Add tenant_id column to pos.alerts if not exists
ALTER TABLE IF EXISTS pos.alerts
  ADD COLUMN IF NOT EXISTS tenant_id VARCHAR(100);

-- Optional index to speed up filtering by tenant
CREATE INDEX IF NOT EXISTS idx_alerts_tenant_id ON pos.alerts(tenant_id);