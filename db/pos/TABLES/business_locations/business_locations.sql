-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: sasdatqbox-db-1
SET LOCAL search_path TO pos;

CREATE TABLE pos.business_locations (
  id uuid NOT NULL,
  business_id uuid NOT NULL,
  name character varying NOT NULL,
  address character varying,
  phone character varying,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
ALTER TABLE pos.business_locations ADD CONSTRAINT business_locations_business_id_fkey FOREIGN KEY (business_id) REFERENCES pos.businesses(id);
ALTER TABLE pos.business_locations ADD CONSTRAINT business_locations_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX business_locations_pkey ON pos.business_locations USING btree (id);
