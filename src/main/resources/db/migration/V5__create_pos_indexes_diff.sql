CREATE INDEX IF NOT EXISTS idx_alerts_created_at ON pos.alerts USING btree (created_at);
CREATE INDEX IF NOT EXISTS idx_alerts_event_id ON pos.alerts USING btree (event_id);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON pos.payments USING btree (created_at);
CREATE INDEX IF NOT EXISTS idx_transfers_created_at ON pos.transfers USING btree (created_at);
CREATE UNIQUE INDEX IF NOT EXISTS ix_pos_customers_email ON pos.customers USING btree (email);
CREATE UNIQUE INDEX IF NOT EXISTS ix_pos_users_email ON pos.users USING btree (email);
CREATE UNIQUE INDEX IF NOT EXISTS products_sku_key ON pos.products USING btree (sku);
