-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: sasdatqbox-db-1
SET LOCAL search_path TO pos;

CREATE TABLE pos.users (
  id uuid NOT NULL,
  email character varying(255) NOT NULL,
  hashed_password character varying(255) NOT NULL,
  role character varying(255),
  is_active boolean,
  is_superuser boolean,
  first_name character varying(255),
  last_name character varying(255),
  phone character varying,
  avatar_url character varying,
  billing_address json,
  payment_method json,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
ALTER TABLE pos.users ADD CONSTRAINT users_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX ix_pos_users_email ON pos.users USING btree (email);
CREATE UNIQUE INDEX users_pkey ON pos.users USING btree (id);
