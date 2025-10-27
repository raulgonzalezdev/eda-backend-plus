-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: sasdatqbox-db-1
SET LOCAL search_path TO pos;

CREATE TABLE pos.messages (
  id uuid NOT NULL,
  conversation_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  read_at timestamp with time zone
);
ALTER TABLE pos.messages ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES pos.users(id);
ALTER TABLE pos.messages ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES pos.conversations(id);
ALTER TABLE pos.messages ADD CONSTRAINT messages_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX messages_pkey ON pos.messages USING btree (id);
