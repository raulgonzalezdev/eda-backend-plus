-- Nota: Flyway ejecuta cada migración en una transacción (no uses BEGIN/COMMIT aquí)
-- Forzar resolución de tipos dentro del esquema 'pos'
SET LOCAL search_path TO pos;

CREATE TABLE IF NOT EXISTS pos.appointment_documents (
  id uuid NOT NULL,
  appointment_id uuid NOT NULL,
  document_type documenttype NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS pos.appointments (
  id uuid NOT NULL,
  doctor_id uuid NOT NULL,
  patient_id uuid NOT NULL,
  status appointmentstatus NOT NULL,
  appointment_datetime timestamp with time zone NOT NULL,
  reason text,
  stripe_payment_intent_id character varying,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS pos.business_locations (
  id uuid NOT NULL,
  business_id uuid NOT NULL,
  name character varying NOT NULL,
  address character varying,
  phone character varying,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS pos.businesses (
  id uuid NOT NULL,
  name character varying NOT NULL,
  address character varying,
  phone character varying,
  email character varying,
  tax_number character varying,
  owner_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS pos.conversation_participants (
  user_id uuid NOT NULL,
  conversation_id uuid NOT NULL
);

CREATE TABLE IF NOT EXISTS pos.conversations (
  id uuid NOT NULL,
  appointment_id uuid,
  type conversationtype NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS pos.customers (
  id uuid NOT NULL,
  first_name character varying NOT NULL,
  last_name character varying NOT NULL,
  email character varying,
  phone character varying,
  stripe_customer_id character varying,
  business_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS pos.inventory (
  id uuid NOT NULL,
  product_id uuid NOT NULL,
  location_id uuid NOT NULL,
  quantity integer NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS pos.messages (
  id uuid NOT NULL,
  conversation_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  read_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS pos.patients (
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

CREATE TABLE IF NOT EXISTS pos.prices (
  id character varying(255) NOT NULL PRIMARY KEY,
  product_id character varying,
  active boolean,
  description character varying,
  unit_amount bigint,
  currency character varying(3),
  type pricingtype,
  "interval" pricingplaninterval,
  interval_count integer,
  trial_period_days integer,
  metadata json,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS pos.products (
  id uuid NOT NULL,
  name character varying NOT NULL,
  description character varying,
  price double precision NOT NULL,
  sku character varying,
  business_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS pos.stock_transfer_items (
  id uuid NOT NULL,
  transfer_id uuid NOT NULL,
  product_id uuid NOT NULL,
  quantity integer NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS pos.stock_transfers (
  id uuid NOT NULL,
  business_id uuid NOT NULL,
  from_location_id uuid NOT NULL,
  to_location_id uuid NOT NULL,
  status character varying NOT NULL,
  notes character varying,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS pos.subscription_products (
  id character varying(255) NOT NULL PRIMARY KEY,
  active boolean,
  name character varying,
  description character varying,
  image character varying,
  metadata json,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS pos.subscriptions (
  id character varying NOT NULL,
  user_id uuid NOT NULL,
  status subscriptionstatus,
  metadata json,
  price_id character varying(255),
  quantity integer,
  cancel_at_period_end boolean,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone,
  current_period_start timestamp with time zone NOT NULL DEFAULT now(),
  current_period_end timestamp with time zone NOT NULL DEFAULT now(),
  ended_at timestamp with time zone,
  cancel_at timestamp with time zone,
  canceled_at timestamp with time zone,
  trial_start timestamp with time zone,
  trial_end timestamp with time zone
);

ALTER TABLE pos.alerts ADD COLUMN kafka_topic character varying(128) DEFAULT 'alerts.suspect'::character varying;
ALTER TABLE pos.alerts ADD COLUMN test character varying(10);
ALTER TABLE pos.outbox ADD COLUMN event_type character varying(255);
ALTER TABLE pos.users ADD COLUMN avatar_url character varying;
ALTER TABLE pos.users ADD COLUMN billing_address json;
ALTER TABLE pos.users ADD COLUMN is_active boolean;
ALTER TABLE pos.users ADD COLUMN is_superuser boolean;
ALTER TABLE pos.users ADD COLUMN payment_method json;
ALTER TABLE pos.users ADD COLUMN phone character varying;
ALTER TABLE pos.users ADD COLUMN updated_at timestamp with time zone;
