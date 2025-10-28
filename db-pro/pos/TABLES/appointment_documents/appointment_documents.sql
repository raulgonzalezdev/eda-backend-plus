-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.appointment_documents (
  id uuid NOT NULL,
  appointment_id uuid NOT NULL,
  document_type pos.documenttype NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
ALTER TABLE pos.appointment_documents ADD CONSTRAINT appointment_documents_pkey PRIMARY KEY (id);
ALTER TABLE pos.appointment_documents ADD CONSTRAINT appointment_documents_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES pos.appointments(id);
CREATE UNIQUE INDEX appointment_documents_pkey ON pos.appointment_documents USING btree (id);
