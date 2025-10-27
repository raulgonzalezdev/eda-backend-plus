-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: sasdatqbox-db-1
SET LOCAL search_path TO pos;

CREATE TABLE pos.conversations (
  id uuid NOT NULL,
  appointment_id uuid,
  type conversationtype NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
ALTER TABLE pos.conversations ADD CONSTRAINT conversations_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES pos.appointments(id);
ALTER TABLE pos.conversations ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX conversations_pkey ON pos.conversations USING btree (id);
