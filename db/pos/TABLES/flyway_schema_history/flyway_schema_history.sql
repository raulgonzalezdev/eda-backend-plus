-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: sasdatqbox-db-1
SET LOCAL search_path TO pos;

CREATE TABLE pos.flyway_schema_history (
  installed_rank integer NOT NULL,
  version character varying(50),
  description character varying(200) NOT NULL,
  type character varying(20) NOT NULL,
  script character varying(1000) NOT NULL,
  checksum integer,
  installed_by character varying(100) NOT NULL,
  installed_on timestamp without time zone NOT NULL DEFAULT now(),
  execution_time integer NOT NULL,
  success boolean NOT NULL
);
ALTER TABLE pos.flyway_schema_history ADD CONSTRAINT flyway_schema_history_pk PRIMARY KEY (installed_rank);
CREATE UNIQUE INDEX flyway_schema_history_pk ON pos.flyway_schema_history USING btree (installed_rank);
CREATE INDEX flyway_schema_history_s_idx ON pos.flyway_schema_history USING btree (success);
