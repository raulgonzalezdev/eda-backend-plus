CREATE TABLE pos.appointment_documents (
  id uuid NOT NULL,
  appointment_id uuid NOT NULL,
  document_type documenttype NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE pos.appointments (
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

CREATE TABLE pos.business_locations (
  id uuid NOT NULL,
  business_id uuid NOT NULL,
  name character varying NOT NULL,
  address character varying,
  phone character varying,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE pos.businesses (
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

CREATE TABLE pos.conversation_participants (
  user_id uuid NOT NULL,
  conversation_id uuid NOT NULL
);

CREATE TABLE pos.conversations (
  id uuid NOT NULL,
  appointment_id uuid,
  type conversationtype NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE pos.customers (
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

CREATE TABLE pos.inventory (
  id uuid NOT NULL,
  product_id uuid NOT NULL,
  location_id uuid NOT NULL,
  quantity integer NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE pos.messages (
  id uuid NOT NULL,
  conversation_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  read_at timestamp with time zone
);

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

CREATE TABLE pos.prices (
  id character varying NOT NULL,
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

CREATE TABLE pos.products (
  id uuid NOT NULL,
  name character varying NOT NULL,
  description character varying,
  price double precision NOT NULL,
  sku character varying,
  business_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE pos.stock_transfer_items (
  id uuid NOT NULL,
  transfer_id uuid NOT NULL,
  product_id uuid NOT NULL,
  quantity integer NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE pos.stock_transfers (
  id uuid NOT NULL,
  business_id uuid NOT NULL,
  from_location_id uuid NOT NULL,
  to_location_id uuid NOT NULL,
  status character varying NOT NULL,
  notes character varying,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE pos.subscription_products (
  id character varying NOT NULL,
  active boolean,
  name character varying,
  description character varying,
  image character varying,
  metadata json,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);

CREATE TABLE pos.subscriptions (
  id character varying NOT NULL,
  user_id uuid NOT NULL,
  status subscriptionstatus,
  metadata json,
  price_id character varying,
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

