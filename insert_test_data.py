import psycopg2
import json
import uuid

import random

conn = psycopg2.connect(
    dbname="sasdatqbox",
    user="sas_user",
    password="ML!gsx90l02",
    host="localhost",
    port="5433"
)

cur = conn.cursor()

payload = {"id": str(uuid.uuid4()), "amount": 2000}

cur.execute(
    "INSERT INTO pos.outbox (id, aggregate_type, aggregate_id, type, payload) VALUES (%s, %s, %s, %s, %s)",
    (
        random.randint(1, 100000),
        'payment',
        '12345',
        'PaymentCreated',
        json.dumps(payload)
    )
)

conn.commit()

cur.close()
conn.close()

print("Test data inserted successfully.")