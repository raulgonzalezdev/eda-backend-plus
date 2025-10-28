-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.patients (
  id uuid NOT NULL,
  user_id uuid NOT NULL,
  first_name character varying NOT NULL,
  last_name character varying NOT NULL,
  date_of_birth date NOT NULL,
  contact_info json,
  medical_history text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
ALTER TABLE pos.patients ADD CONSTRAINT patients_user_id_fkey FOREIGN KEY (user_id) REFERENCES pos.users(id);
ALTER TABLE pos.patients ADD CONSTRAINT patients_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX patients_pkey ON pos.patients USING btree (id);
