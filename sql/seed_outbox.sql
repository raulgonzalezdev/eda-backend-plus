-- Inserta un evento de prueba en la tabla outbox
INSERT INTO pos.outbox (id, aggregate_type, aggregate_id, type, payload)
VALUES (
  floor(random()*100000)::int,
  'payment',
  '12345',
  'PaymentCreated',
  '{"id":"test-1","amount":2000}'
);