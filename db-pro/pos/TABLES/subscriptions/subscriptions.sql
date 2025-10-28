-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.subscriptions (
  id character varying NOT NULL,
  user_id uuid NOT NULL,
  status pos.subscriptionstatus,
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
ALTER TABLE pos.subscriptions ADD CONSTRAINT subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES pos.users(id);
ALTER TABLE pos.subscriptions ADD CONSTRAINT subscriptions_price_id_fkey FOREIGN KEY (price_id) REFERENCES pos.prices(id);
ALTER TABLE pos.subscriptions ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX subscriptions_pkey ON pos.subscriptions USING btree (id);
