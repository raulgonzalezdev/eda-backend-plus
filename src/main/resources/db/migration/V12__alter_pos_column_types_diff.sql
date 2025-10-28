-- Schema: pos
-- Nota: Flyway ejecuta cada migración en una transacción
SET LOCAL search_path TO pos;

ALTER TABLE pos.alerts ALTER COLUMN alert_type TYPE alert_type character varying(255) USING alert_type::alert_type character varying(255);
ALTER TABLE pos.alerts ALTER COLUMN amount TYPE amount double precision USING amount::amount double precision;
ALTER TABLE pos.alerts ALTER COLUMN event_id TYPE event_id character varying(255) USING event_id::event_id character varying(255);
ALTER TABLE pos.alerts ALTER COLUMN kafka_partition TYPE kafka_partition integer USING kafka_partition::kafka_partition integer;
ALTER TABLE pos.alerts ALTER COLUMN source_type TYPE source_type character varying(255) USING source_type::source_type character varying(255);
ALTER TABLE pos.appointment_documents ALTER COLUMN document_type TYPE document_type documenttype USING document_type::document_type documenttype;
ALTER TABLE pos.appointments ALTER COLUMN status TYPE status appointmentstatus USING status::status appointmentstatus;
ALTER TABLE pos.conversations ALTER COLUMN type TYPE type conversationtype USING type::type conversationtype;
ALTER TABLE pos.outbox ALTER COLUMN aggregate_id TYPE aggregate_id character varying(255) USING aggregate_id::aggregate_id character varying(255);
ALTER TABLE pos.outbox ALTER COLUMN aggregate_type TYPE aggregate_type character varying(255) USING aggregate_type::aggregate_type character varying(255);
ALTER TABLE pos.outbox ALTER COLUMN type TYPE type character varying(255) USING type::type character varying(255);
ALTER TABLE pos.payments ALTER COLUMN account_id TYPE account_id character varying(255) USING account_id::account_id character varying(255);
ALTER TABLE pos.payments ALTER COLUMN amount TYPE amount double precision USING amount::amount double precision;
ALTER TABLE pos.payments ALTER COLUMN currency TYPE currency character varying(255) USING currency::currency character varying(255);
ALTER TABLE pos.payments ALTER COLUMN id TYPE id character varying(255) USING id::id character varying(255);
ALTER TABLE pos.payments ALTER COLUMN type TYPE type character varying(255) USING type::type character varying(255);
ALTER TABLE pos.prices ALTER COLUMN "interval" TYPE "interval" pricingplaninterval USING "interval"::"interval" pricingplaninterval;
ALTER TABLE pos.prices ALTER COLUMN type TYPE type pricingtype USING type::type pricingtype;
ALTER TABLE pos.subscriptions ALTER COLUMN status TYPE status subscriptionstatus USING status::status subscriptionstatus;
ALTER TABLE pos.transfers ALTER COLUMN amount TYPE amount double precision USING amount::amount double precision;
ALTER TABLE pos.transfers ALTER COLUMN from_account TYPE from_account character varying(255) USING from_account::from_account character varying(255);
ALTER TABLE pos.transfers ALTER COLUMN id TYPE id character varying(255) USING id::id character varying(255);
ALTER TABLE pos.transfers ALTER COLUMN to_account TYPE to_account character varying(255) USING to_account::to_account character varying(255);
ALTER TABLE pos.transfers ALTER COLUMN type TYPE type character varying(255) USING type::type character varying(255);
ALTER TABLE pos.users ALTER COLUMN first_name TYPE first_name character varying(255) USING first_name::first_name character varying(255);
ALTER TABLE pos.users ALTER COLUMN last_name TYPE last_name character varying(255) USING last_name::last_name character varying(255);
ALTER TABLE pos.users ALTER COLUMN role TYPE role character varying(255) USING role::role character varying(255);
