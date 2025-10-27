-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.users (
  id uuid NOT NULL,
  email character varying(255),
  hashed_password character varying(255),
  role character varying(255),
  first_name character varying(255),
  last_name character varying(255),
  created_at timestamp with time zone DEFAULT now()
);
ALTER TABLE pos.users ADD CONSTRAINT users_pkey PRIMARY KEY (id);
ALTER TABLE pos.users ADD CONSTRAINT users_email_key UNIQUE (email);
CREATE UNIQUE INDEX users_email_key ON pos.users USING btree (email);
CREATE UNIQUE INDEX users_pkey ON pos.users USING btree (id);
