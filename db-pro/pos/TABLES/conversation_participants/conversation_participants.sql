-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.conversation_participants (
  user_id uuid NOT NULL,
  conversation_id uuid NOT NULL
);
ALTER TABLE pos.conversation_participants ADD CONSTRAINT conversation_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES pos.users(id);
ALTER TABLE pos.conversation_participants ADD CONSTRAINT conversation_participants_pkey PRIMARY KEY (user_id, conversation_id);
ALTER TABLE pos.conversation_participants ADD CONSTRAINT conversation_participants_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES pos.conversations(id);
CREATE UNIQUE INDEX conversation_participants_pkey ON pos.conversation_participants USING btree (user_id, conversation_id);
