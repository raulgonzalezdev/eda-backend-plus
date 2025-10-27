-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: sasdatqbox-db-1
SET LOCAL search_path TO pos;

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
ALTER TABLE pos.appointments ADD CONSTRAINT appointments_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES pos.users(id);
ALTER TABLE pos.appointments ADD CONSTRAINT appointments_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES pos.patients(id);
ALTER TABLE pos.appointments ADD CONSTRAINT appointments_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX appointments_pkey ON pos.appointments USING btree (id);
