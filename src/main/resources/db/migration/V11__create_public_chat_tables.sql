-- Migration: V11__create_public_chat_tables.sql
-- Description: Create chat tables in public schema for Conversation/Message
-- Created: 2025-11-10 21:15:00 -04:00
-- Schema: public
-- Nota: Flyway ejecuta cada migración en una transacción (no uses BEGIN/COMMIT aquí)
SET LOCAL search_path TO public;

-- Conversations table (matches JPA entity Conversation)
CREATE TABLE IF NOT EXISTS public.conversations (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL
);

-- Messages table (matches JPA entity Message)
CREATE TABLE IF NOT EXISTS public.messages (
  id BIGSERIAL PRIMARY KEY,
  content TEXT NOT NULL,
  sender VARCHAR(255) NOT NULL,
  sent_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  conversation_id BIGINT NOT NULL,
  CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id)
    REFERENCES public.conversations(id) ON DELETE CASCADE
);

-- Helpful index for retrieving messages by conversation
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages(conversation_id);