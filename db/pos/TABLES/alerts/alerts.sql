-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: sasdatqbox-db-1
SET LOCAL search_path TO pos;

CREATE TABLE pos.alerts (
  id bigint NOT NULL DEFAULT nextval('pos.alerts_id_seq'::regclass),
  event_id character varying(255),
  alert_type character varying(255),
  source_type character varying(255),
  amount double precision,
  payload jsonb,
  kafka_topic character varying(128) DEFAULT 'alerts.suspect'::character varying,
  kafka_partition integer,
  kafka_offset bigint,
  created_at timestamp with time zone DEFAULT now(),
  test character varying(10)
);
ALTER TABLE pos.alerts ADD CONSTRAINT alerts_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX alerts_pkey ON pos.alerts USING btree (id);
CREATE INDEX idx_alerts_created_at ON pos.alerts USING btree (created_at);
CREATE INDEX idx_alerts_event_id ON pos.alerts USING btree (event_id);
