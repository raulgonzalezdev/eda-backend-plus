-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.customers (
  id uuid NOT NULL,
  first_name character varying NOT NULL,
  last_name character varying NOT NULL,
  email character varying,
  phone character varying,
  stripe_customer_id character varying,
  business_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
ALTER TABLE pos.customers ADD CONSTRAINT customers_user_id_fkey FOREIGN KEY (user_id) REFERENCES pos.users(id);
ALTER TABLE pos.customers ADD CONSTRAINT customers_business_id_fkey FOREIGN KEY (business_id) REFERENCES pos.businesses(id);
ALTER TABLE pos.customers ADD CONSTRAINT customers_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX customers_pkey ON pos.customers USING btree (id);
CREATE UNIQUE INDEX ix_pos_customers_email ON pos.customers USING btree (email);
