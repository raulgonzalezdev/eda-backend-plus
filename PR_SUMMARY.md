# PR Summary: Remove `pos` Schema Prefix from SQL Queries

## Title
fix(db): remove pos schema prefix from SQL queries

## Purpose
This PR removes the hard-coded `pos.` schema prefix from SQL queries in repository classes, switching them to use the default schema (public) instead. This provides more flexibility in database configuration and follows PostgreSQL best practices of using the default schema unless explicitly needed.

## Files Modified
The following repository classes had their SQL queries updated to remove the `pos.` schema prefix:

1. **OutboxRepository.java**
   - `INSERT INTO pos.outbox` → `INSERT INTO outbox`
   - `SELECT ... FROM pos.outbox` → `SELECT ... FROM outbox`
   - `UPDATE pos.outbox` → `UPDATE outbox`

2. **PaymentRepository.java**
   - `INSERT INTO pos.payments` → `INSERT INTO payments`

3. **TransferRepository.java**
   - `INSERT INTO pos.transfers` → `INSERT INTO transfers`

4. **UserRepository.java**
   - `SELECT ... FROM pos.users` → `SELECT ... FROM users`
   - `INSERT INTO pos.users` → `INSERT INTO users`
   - `UPDATE pos.users` → `UPDATE users`
   - `DELETE FROM pos.users` → `DELETE FROM users`

5. **AlertsRepository.java**
   - `INSERT INTO pos.alerts` → `INSERT INTO alerts`
   - `SELECT ... FROM pos.alerts` → `SELECT ... FROM alerts`

## Testing Steps

### 1. Build the Application
```bash
mvn clean package
```

### 2. Run the Application
```bash
java -jar target/eda-backend-0.1.0.jar
```

### 3. Test POST /events/payments Endpoint
```bash
curl -v -X POST http://localhost:8080/events/payments \
  -H "Content-Type: application/json" \
  -d '{
    "id": "p-123",
    "type": "payment",
    "amount": 12000,
    "currency": "EUR",
    "accountId": "acc-1"
  }'
```

### 4. Verify Database Schema
If you prefer to keep using the `pos` schema, you can run the SQL script to create it:
```bash
psql -h <PG_HOST> -U <PG_USER> -d <PG_DATABASE> -f sql/create_pos_schema_and_tables.sql
```

Then update the application to use the `pos` schema by either:
- Setting the default schema in the database connection
- Or reverting these changes and using the `pos.` prefix in queries

## Notes
- Branch protection rules may require reviews or CI checks before merging
- The application will now use the default schema (typically `public`) for all database operations
- Users who want to continue using a custom schema can configure it via database settings
