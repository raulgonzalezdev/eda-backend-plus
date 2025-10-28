-- Migration: V2_1__create_pos_enums.sql
-- Created: 2025-10-28
-- Schema: pos
-- Nota: Flyway ejecuta cada migración en una transacción (no uses BEGIN/COMMIT aquí)
SET LOCAL search_path TO pos;

-- Crear tipos ENUM faltantes de forma idempotente
DO $$
BEGIN
  -- documenttype
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'pos' AND t.typname = 'documenttype'
  ) THEN
    EXECUTE 'CREATE TYPE pos.documenttype AS ENUM (
      ''prescription'',
      ''lab_result'',
      ''invoice'',
      ''referral'',
      ''note''
    )';
  END IF;

  -- appointmentstatus
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'pos' AND t.typname = 'appointmentstatus'
  ) THEN
    EXECUTE 'CREATE TYPE pos.appointmentstatus AS ENUM (
      ''scheduled'',
      ''confirmed'',
      ''completed'',
      ''canceled'',
      ''no_show'',
      ''rescheduled''
    )';
  END IF;

  -- conversationtype
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'pos' AND t.typname = 'conversationtype'
  ) THEN
    EXECUTE 'CREATE TYPE pos.conversationtype AS ENUM (
      ''chat'',
      ''support'',
      ''appointment'',
      ''followup''
    )';
  END IF;

  -- pricingtype
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'pos' AND t.typname = 'pricingtype'
  ) THEN
    EXECUTE 'CREATE TYPE pos.pricingtype AS ENUM (
      ''one_time'',
      ''recurring''
    )';
  END IF;

  -- pricingplaninterval
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'pos' AND t.typname = 'pricingplaninterval'
  ) THEN
    EXECUTE 'CREATE TYPE pos.pricingplaninterval AS ENUM (
      ''day'',
      ''week'',
      ''month'',
      ''year''
    )';
  END IF;

  -- subscriptionstatus
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'pos' AND t.typname = 'subscriptionstatus'
  ) THEN
    EXECUTE 'CREATE TYPE pos.subscriptionstatus AS ENUM (
      ''active'',
      ''trialing'',
      ''canceled'',
      ''past_due'',
      ''incomplete'',
      ''incomplete_expired'',
      ''paused'',
      ''unpaid''
    )';
  END IF;
END$$;