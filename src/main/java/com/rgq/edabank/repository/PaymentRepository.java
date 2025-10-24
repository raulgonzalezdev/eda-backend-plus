package com.rgq.edabank.repository;

import com.rgq.edabank.model.Payment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class PaymentRepository {
    private final JdbcTemplate jdbc;

    public PaymentRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void insertPayment(Payment p) {
        try {
            jdbc.update("INSERT INTO pos.payments (id,type,amount,currency,account_id,payload) VALUES (?,?,?,?,?,?::jsonb)",
                    p.getId(), p.getType(), p.getAmount(), p.getCurrency(), p.getAccountId(), p.getPayload());
        } catch (Exception e) {
            io.micrometer.core.instrument.Metrics.counter("persist.failures", "entity", "payment").increment();
            throw e;
        }
    }
}
