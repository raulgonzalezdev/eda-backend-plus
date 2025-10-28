-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.users (
  id uuid NOT NULL,
  email character varying(255),
  hashed_password character varying(255),
  role character varying(50),
  first_name character varying(100),
  last_name character varying(100),
  created_at timestamp with time zone DEFAULT now(),
  avatar_url character varying,
  billing_address json,
  is_active boolean,
  is_superuser boolean,
  payment_method json,
  phone character varying,
  updated_at timestamp with time zone
);
ALTER TABLE pos.users ADD CONSTRAINT users_pkey PRIMARY KEY (id);
ALTER TABLE pos.users ADD CONSTRAINT users_email_key UNIQUE (email);
CREATE UNIQUE INDEX ix_pos_users_email ON pos.users USING btree (email);
CREATE UNIQUE INDEX users_email_key ON pos.users USING btree (email);
CREATE UNIQUE INDEX users_pkey ON pos.users USING btree (id);
