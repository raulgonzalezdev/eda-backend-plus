-- Script para insertar datos de prueba en pos.outbox
INSERT INTO pos.outbox (aggregate_type, aggregate_id, type, payload, sent) 
VALUES ('Payment', 'test-456', 'PaymentCreated', '{"amount": 15000.00, "currency": "USD", "userId": "user-456"}', false);